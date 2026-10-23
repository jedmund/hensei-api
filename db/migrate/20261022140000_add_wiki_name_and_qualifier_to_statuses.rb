# frozen_string_literal: true

# Status names without the wiki's trailing level number (D59): "Jade Crest 1" shows as Jade Crest.
# statuses.wiki_name keeps the wiki name the skill build keys a status by (name_key stays its
# normalized form, so no key changes); name_en becomes the name shown. Two statuses that would show
# the same name ("Asleep 1" and "Asleep") are told apart by statuses.qualifier, not by a suffix.
#
# The repair (CharacterSkills::StatusCatalogueRepair) runs inline: it merges Irresistible Treats into
# Irresistible Treat (data/statuses/aliases.json), deletes the misread "a=10%" status, and sets the
# shown names and qualifiers (CharacterSkills::StatusDisplayNames) before the unique index needs them.
class AddWikiNameAndQualifierToStatuses < ActiveRecord::Migration[8.1]
  def up
    add_column :statuses, :wiki_name, :string
    add_column :statuses, :qualifier, :string
    execute 'UPDATE statuses SET wiki_name = name_en'
    change_column_null :statuses, :wiki_name, false

    counts = CharacterSkills::StatusCatalogueRepair.call(connection)
    display = counts.delete(:display)
    say "Repair: #{counts}"
    say "Shown names: #{display[:renamed]} renamed, #{display[:qualified].size} qualified " \
        "(#{display[:qualified].map { |q| "#{q[:name_en]} (#{q[:qualifier]})" }.join(', ')})"

    add_index :statuses, %i[name_en qualifier], unique: true, nulls_not_distinct: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'the merged and deleted statuses can\'t be restored'
  end
end
