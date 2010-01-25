require 'hickey'
require 'dm-migrations/migration_runner'

migration(1, :create_pages) do
  up do
    create_table :pages do
      column :id, DataMapper::Types::Serial
      column :slug, String, :length => 255, :index => true
      column :title, String, :length => 255
      column :body, DataMapper::Types::Text
      column :rendered_body, DataMapper::Types::Text
      column :version, Integer, :default => 0, :index => true
      column :editor_name, String, :length => 255, :default => "nobody"
      column :editor_ip, String
      column :created_at, DateTime
    end
  end
  down do
    drop_table :pages
  end
end

migration(2, :create_math_problems) do
  up do
    create_table :math_problems do
      column :id, DataMapper::Types::Serial
      column :first, Integer
      column :second, Integer
      column :operator, String
    end
  end
  down do
    drop_table :math_problems
  end
end

migration(3, :add_text_indexing_to_pages) do
  up do
    ADD_TEXT_INDEXING_TO_MEMORY = <<-EOF 
      ALTER TABLE pages ADD COLUMN title_search_index tsvector;
      ALTER TABLE pages ADD COLUMN body_search_index tsvector;
  
      UPDATE pages SET title_search_index = to_tsvector('english', coalesce(title,''));
      UPDATE pages SET body_search_index = to_tsvector('english', coalesce(body,''));
        
      CREATE TRIGGER title_index_update BEFORE INSERT OR UPDATE ON pages FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger(title_search_index, 'pg_catalog.english', title);
      CREATE TRIGGER body_index_update BEFORE INSERT OR UPDATE ON pages FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger(body_search_index, 'pg_catalog.english', body);
    EOF
    repository.adapter.execute(ADD_TEXT_INDEXING_TO_MEMORY)
  end
  down do
    REMOVE_TEXT_INDEXING_TO_MEMORY = <<-EOF
      ALTER TABLE pages DROP COLUMN title_search_index;
      ALTER TABLE pages DROP COLUMN body_search_index;
      DROP TRIGGER title_index_update;
      DROP TRIGGER body_index_update;
    EOF
    repository.adapter.execute(REMOVE_TEXT_INDEXING_TO_MEMORY)
  end
end



if $0 == __FILE__
  if $*.first == "down"
    migrate_down!
  else
    migrate_up!
  end
end