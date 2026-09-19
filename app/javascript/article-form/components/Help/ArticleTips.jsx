import { h } from 'preact';

export const ArticleTips = () => (
  <div
    data-testid="article-publishing-tips"
    className="crayons-article-form__help crayons-article-form__help--tags"
  >
    <h4 className="mb-2 fs-l">Tipps zum Veröffentlichen</h4>
    <ul className="list-disc pl-6 color-base-70">
      <li>
        Stelle sicher, dass dein Beitrag ein Titelbild hat, um in der Startseite
        und auf Social-Media-Plattformen optimal angezeigt zu werden.
      </li>
      <li>
        Teile deinen Beitrag auf Social-Media-Plattformen oder mit Kollegen oder
        lokalen Communities.
      </li>
      <li>
        Bitte Leute, Fragen in den Kommentaren zu hinterlassen. Das ist eine
        großartige Möglichkeit, um zusätzliche Diskussionen anzuregen und
        persönlich zu beschreiben, warum du den Beitrag geschrieben hast oder
        warum andere ihn hilfreich finden könnten.
      </li>
    </ul>
  </div>
);
