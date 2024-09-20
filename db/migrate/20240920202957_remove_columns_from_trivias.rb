class RemoveColumnsFromTrivias < ActiveRecord::Migration[7.0]
  def change
    remove_column :trivias, :translated_questions
    remove_column :trivias, :selected_language_code
  end
end
