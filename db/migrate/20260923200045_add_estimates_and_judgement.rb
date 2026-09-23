class AddEstimatesAndJudgement < ActiveRecord::Migration[8.1]
  def change
    add_column :components, :shelf_life_note, :string

    add_column :decompositions, :verdict, :string
    add_column :decompositions, :reason, :text
    add_column :decompositions, :caveats, :json
    add_column :decompositions, :plan, :json
    add_column :decompositions, :line_ids, :json
  end
end
