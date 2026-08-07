class MakeConversationsContactIdIndexUnique < ActiveRecord::Migration[7.1]
  INDEX_NAME = 'index_conversations_on_contact_id'.freeze

  # Production already carries a unique index on contact_id after a manual
  # change, so match on the indexed column rather than the index name: we can
  # not assume the hand written index kept the name Rails generated.
  def up
    return if contact_id_indexes.any?(&:unique)

    contact_id_indexes.each { |index| remove_index :conversations, name: index.name }
    add_index :conversations, :contact_id, name: INDEX_NAME, unique: true
  end

  def down
    return unless contact_id_indexes.any?(&:unique)

    contact_id_indexes.each { |index| remove_index :conversations, name: index.name }
    add_index :conversations, :contact_id, name: INDEX_NAME
  end

  private

  def contact_id_indexes
    connection.indexes(:conversations).select { |index| index.columns == ['contact_id'] }
  end
end
