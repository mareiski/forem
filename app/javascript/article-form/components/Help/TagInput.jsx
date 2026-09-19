import { h } from 'preact';

export const TagInput = () => (
  <div
    data-testid="basic-tag-input-help"
    className="crayons-article-form__help crayons-article-form__help--tags"
  >
    <h4 className="mb-2 fs-l">Richtlinien für Tags</h4>
    <ul className="list-disc pl-6 color-base-70">
      <li>
        Tags helfen Leuten, deinen Beitrag zu finden – betrachte sie als Themen
        oder Kategorien, die deinen Beitrag am besten beschreiben.
      </li>
      <li>
        Füge bis zu vier durch Kommas getrennte Tags pro Beitrag hinzu. Verwende
        möglichst bestehende Tags.
      </li>
      <li>
        Einige Tags haben spezielle Richtlinien für Beiträge – überprüfe genau,
        ob dein Beitrag diesen entspricht.
      </li>
    </ul>
  </div>
);
