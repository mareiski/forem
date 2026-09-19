import { h } from 'preact';
import PropTypes from 'prop-types';

export const EditorFormattingHelp = ({ openModal }) => (
  <div
    data-testid="format-help"
    className="crayons-article-form__help crayons-article-form__help--body"
  >
    <h4 className="mb-2 fs-l">Editor-Grundlagen</h4>
    <ul className="list-disc pl-6 color-base-70">
      <li>
        Verwende{' '}
        <a href="#markdown" onClick={() => openModal('markdownShowing')}>
          Markdown
        </a>{' '}
        um Beiträge zu schreiben und zu formatieren.
        <details className="fs-s my-1">
          <summary class="cursor-pointer">Häufig verwendete Syntax</summary>
          <table className="crayons-card crayons-card--secondary crayons-table crayons-table--compact w-100 mt-2 mb-4 lh-tight">
            <tbody>
              <tr>
                <td className="ff-monospace">
                  # Header
                  <br />
                  ...
                  <br />
                  ###### Header
                </td>
                <td>
                  H1-Überschrift
                  <br />
                  ...
                  <br />
                  H6-Überschrift
                </td>
              </tr>
              <tr>
                <td className="ff-monospace">*kursiv* oder _kursiv_</td>
                <td>
                  <em>kursiv</em>
                </td>
              </tr>
              <tr>
                <td className="ff-monospace">**fett**</td>
                <td>
                  <strong>fett</strong>
                </td>
              </tr>
              <tr>
                <td className="ff-monospace">[Link](https://...)</td>
                <td>
                  <a href="https://forem.com">Link</a>
                </td>
              </tr>
              <tr>
                <td className="ff-monospace">
                  * Punkt 1<br />* Punkt 2
                </td>
                <td>
                  <ul class="list-disc ml-5">
                    <li>Punkt 1</li>
                    <li>Punkt 2</li>
                  </ul>
                </td>
              </tr>
              <tr>
                <td className="ff-monospace">
                  1. Punkt 1<br />
                  2. Punkt 2
                </td>
                <td>
                  <ul class="list-decimal ml-5">
                    <li>Punkt 1</li>
                    <li>Punkt 2</li>
                  </ul>
                </td>
              </tr>
              <tr>
                <td className="ff-monospace">&gt; zitierter Text</td>
                <td>
                  <span className="pl-2 border-0 border-solid border-l-2 border-base-50">
                    zitierter Text
                  </span>
                </td>
              </tr>
              <tr>
                <td className="ff-monospace">`Inline-Code`</td>
                <td>
                  <code>Inline-Code</code>
                </td>
              </tr>
              <tr>
                <td className="ff-monospace">
                  <span class="fs-xs">```</span>
                  <br />
                  Code-Block
                  <br />
                  <span class="fs-xs">```</span>
                </td>
                <td>
                  <div class="highlight p-2 overflow-hidden">
                    <code>Code-Block</code>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </details>
      </li>
      <li>
        Bette reichhaltige Inhalte wie Tweets, YouTube-Videos usw. ein. Verwende die
        vollständige URL: <code>{'{% embed https://... %}.'}</code>{' '}
        <a href="#liquid" onClick={() => openModal('liquidShowing')}>
          Liste der unterstützten Einbettungen anzeigen
        </a>
        .
      </li>
      <li>
        Zusätzlich zu Bildern für den Inhalt deines Beitrags kannst du auch ein
        Titelbild per Drag &amp; Drop hinzufügen.
      </li>
      <li>
        Bette Codier-Sitzungen von Claude Code, Codex, Gemini CLI und anderen ein:{' '}
        <code>{'{% agent_session ID %}'}</code>. Verwende benannte Ausschnitte, um
        verschiedene Teile in deinem Beitrag einzubetten:{' '}
        <code>{'{% agent_session ID planning %}'}</code>.{' '}
        <a href="/agent_sessions/new" target="_blank" rel="noopener noreferrer">
          Eine Sitzung hochladen
        </a>
        .
      </li>
    </ul>
  </div>
);

EditorFormattingHelp.propTypes = {
  openModal: PropTypes.func.isRequired,
};
