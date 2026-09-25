import { h, Fragment } from 'preact';
import { useCallback, useState } from 'preact/hooks';
import PropTypes from 'prop-types';
import { ImageUploader } from './ImageUploader';
import { ButtonNew as Button, MarkdownToolbar, Link, Modal } from '@crayons';
import HelpIcon from '@images/help.svg';
import AgentSessionIcon from '@images/agent-session.svg';
import RoadlioIcon from '@images/logo_bw.svg';

const ROADLIO_MAP_MODE = 'map';
const ROADLIO_SCHEDULE_MODE = 'schedule';

const RoadlioToolbarIcon = ({ className, ...props }) => (
  <RoadlioIcon
    {...props}
    width="24"
    height="24"
    className={`${className || ''} crayons-icon--default`}
  />
);

const insertTextAtCursor = ({ textAreaId, text }) => {
  const textArea = document.getElementById(textAreaId);

  if (!textArea) return;

  const { selectionStart, selectionEnd, value } = textArea;

  textArea.value = `${value.slice(0, selectionStart)}${text}${value.slice(
    selectionEnd,
  )}`;
  textArea.dispatchEvent(new Event('input'));
  textArea.focus({ preventScroll: true });

  const cursorPosition = selectionStart + text.length;
  textArea.setSelectionRange(cursorPosition, cursorPosition);
};

const RoadlioLiquidTagButton = ({ textAreaId, ...buttonProps }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [url, setUrl] = useState('');
  const [mode, setMode] = useState(ROADLIO_SCHEDULE_MODE);

  const closeModal = useCallback(() => setIsOpen(false), []);
  const openModal = useCallback(() => {
    setUrl('');
    setMode(ROADLIO_SCHEDULE_MODE);
    setIsOpen(true);
  }, []);

  const handleInsert = (event) => {
    event.preventDefault();

    const trimmedUrl = url.trim();
    if (!trimmedUrl) return;

    const finalUrl =
      mode === ROADLIO_MAP_MODE
        ? `${trimmedUrl.replace(/\/$/, '')}/Karte`
        : trimmedUrl;

    insertTextAtCursor({
      textAreaId,
      text: `{% roadlio ${finalUrl} %}`,
    });

    setIsOpen(false);
    setUrl('');
    setMode(ROADLIO_SCHEDULE_MODE);
  };

  return (
    <Fragment>
      <Button
        {...buttonProps}
        icon={RoadlioToolbarIcon}
        aria-label="Reise anfügen"
        title="Reise anfügen"
        onClick={openModal}
      />

      {isOpen && (
        <Modal
          title="Reise anfügen"
          onClose={closeModal}
          backdropDismissible
          size="small"
        >
          <form onSubmit={handleInsert} className="p-4">
            <label className="crayons-field mb-4">
              <span className="crayons-field__label">URL</span>
              <input
                type="url"
                className="crayons-textfield"
                value={url}
                onInput={(event) => setUrl(event.target.value)}
                required
              />
            </label>

            <fieldset className="mb-4">
              <legend className="crayons-field__label mb-2">Ansicht</legend>
              <label className="crayons-field crayons-field--radio mb-2">
                <input
                  type="radio"
                  name="roadlioMode"
                  value="map"
                  checked={mode === ROADLIO_MAP_MODE}
                  onChange={() => setMode(ROADLIO_MAP_MODE)}
                  className="crayons-radio"
                />
                <span className="crayons-field__label">Karte</span>
              </label>
              <label className="crayons-field crayons-field--radio">
                <input
                  type="radio"
                  name="roadlioMode"
                  value={ROADLIO_SCHEDULE_MODE}
                  checked={mode === ROADLIO_SCHEDULE_MODE}
                  onChange={() => setMode(ROADLIO_SCHEDULE_MODE)}
                  className="crayons-radio"
                />
                <span className="crayons-field__label">Zeitplan</span>
              </label>
            </fieldset>

            <div className="flex justify-end gap-2">
              <Button variant="secondary" onClick={closeModal}>
                Cancel
              </Button>
              <Button variant="primary" type="submit">
                OK
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </Fragment>
  );
};

export const Toolbar = ({ version, textAreaId }) => {
  return (
    <div
      className={`crayons-article-form__toolbar ${version === 'v1' ? 'border-t-0' : ''
        }`}
    >
      {version === 'v1' ? (
        <div className="flex items-center">
          <ImageUploader editorVersion={version} />
          <a
            href="/agent_sessions/new"
            target="_blank"
            rel="noopener noreferrer"
            className="c-btn ml-2"
            title="Upload Agent Session"
          >
            Agent Session
          </a>
        </div>
      ) : (
        <MarkdownToolbar
          textAreaId={textAreaId}
          hiddenFormatters={['code', 'codeBlock', 'embed']}
          additionalPrimaryToolbarElements={[
            <RoadlioLiquidTagButton
              key="roadlio-liquid-tag-button"
              textAreaId={textAreaId}
            />,
            <Link
              key="agent-session-link"
              href="/agent_sessions/new"
              target="_blank"
              rel="noopener noreferrer"
              icon={AgentSessionIcon}
              aria-label="Upload Agent Session"
              title="Upload Agent Session"
            />,
          ]}
          additionalSecondaryToolbarElements={[
            <Link
              key="help-link"
              block
              href="#"
              onClick={(e) => {
                e.preventDefault();
                document.dispatchEvent(new Event('toggle-editor-guide'));
              }}
              icon={HelpIcon}
              aria-label="Help"
              title="Help"
            />,
          ]}
        />
      )}
    </div>
  );
};

Toolbar.propTypes = {
  version: PropTypes.string.isRequired,
  textAreaId: PropTypes.string.isRequired,
};

RoadlioLiquidTagButton.propTypes = {
  textAreaId: PropTypes.string.isRequired,
};

RoadlioToolbarIcon.propTypes = {
  className: PropTypes.string,
};

Toolbar.displayName = 'Toolbar';
