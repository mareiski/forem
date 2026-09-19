import { h } from 'preact';

export const ArticleFormTitle = () => (
  <div
    data-testid="title-help"
    className="crayons-article-form__help crayons-article-form__help--title"
  >
    <h4 className="mb-2 fs-l">Einen großartigen Beitragstitel schreiben</h4>
    <ul className="list-disc pl-6 color-base-70">
      <li>
        Stell dir deinen Beitragstitel als eine sehr kurze (aber fesselnde!)
        Beschreibung vor — wie eine Übersicht über den eigentlichen Beitrag in
        einem kurzen Satz.
      </li>
      <li>
        Verwende bei Bedarf passende Schlüsselwörter, damit Leute deinen Beitrag
        über die Suche finden können.
      </li>
    </ul>
  </div>
);
