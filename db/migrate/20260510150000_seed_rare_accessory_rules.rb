class SeedRareAccessoryRules < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Seeds rules for very rare mainhand bullets and manaturas. All are scored
  # under the `accessory` component since they're gated like accessories
  # (one slot per party) rather than like weapon investment.
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    rules.each do |attrs|
      DifficultyRule.find_or_create_by!(name: attrs[:name]) do |r|
        r.assign_attributes(attrs.merge(active: true))
      end
    end
  end

  def down
    DifficultyRule.where(name: rules.map { |r| r[:name] }).delete_all
  end

  private

  def rules
    [
      # Mainhand bullets ---------------------------------------------------
      { name: 'Mainhand: top-tier Expert Model bullet',  component: 'accessory',
        rule_type: 'mainhand_bullet_match', weight: 6.0,
        params: { 'bullet_ids' => %w[
          9a063ae4-8aed-427a-b029-08fd0c1b0364
          a73e97e1-3e68-47ec-9c90-7b7fd1c2f29f
          17defece-d8d7-4108-95ca-504533dd0ac9
        ] } },
      { name: 'Mainhand: high-tier Expert Model bullet', component: 'accessory',
        rule_type: 'mainhand_bullet_match', weight: 3.5,
        params: { 'bullet_ids' => %w[
          9eb5962e-8a90-4734-8da6-49e8d3194212
          ba6e03ac-1eec-4bb6-9282-96d0a834836a
        ] } },

      # Manaturas ----------------------------------------------------------
      { name: 'Top-tier manatura',                       component: 'accessory',
        rule_type: 'accessory_match', weight: 6.0,
        params: { 'accessory_ids' => %w[
          a2cf6934-deab-4082-8eb8-6ec3c9c0d53e
          70db38f8-3761-4c10-815d-17ab02db527b
        ] } },
      { name: 'High-tier manatura',                      component: 'accessory',
        rule_type: 'accessory_match', weight: 3.5,
        params: { 'accessory_ids' => %w[
          f4b79884-95e8-4a7a-a559-69de2badd69f
          0a8e472c-cc48-4284-b4c1-0b72790e3af3
          c38626f0-a8bf-466b-aa35-d26466576864
        ] } },
      { name: 'Unobtainable collab manatura (Chachazero)', component: 'accessory',
        rule_type: 'accessory_match', weight: 8.0,
        params: { 'accessory_ids' => %w[fa567a0a-70ea-43e4-8bbc-7fab28fb9dae] } }
    ]
  end
  # rubocop:enable Metrics/MethodLength
end
