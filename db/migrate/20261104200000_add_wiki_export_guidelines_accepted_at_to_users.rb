# frozen_string_literal: true

# When the user accepted the notice that gbf.wiki exports don't necessarily
# meet the wiki's guidelines. Accepting once per account unlocks the export.
class AddWikiExportGuidelinesAcceptedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :wiki_export_guidelines_accepted_at, :datetime
  end
end
