require "pg"

class DatabasePersistence
  JOINED_TABLE_STATEMENT = <<~SQL
    SELECT lists.id AS list_id, lists.name AS list_name,
           todos.id AS todo_id, todos.name AS todo_name, completed
      FROM lists LEFT OUTER JOIN todos
        ON lists.id = todos.list_id
  SQL

  def initialize(logger)
    @db = PG.connect(dbname: "todos")
    @logger = logger
  end

  def find_list(id)
    sql = JOINED_TABLE_STATEMENT + " WHERE lists.id = $1"
    result = query(sql, id)
    transform_sql_table(result).first
  end

  def all_lists
    sql = JOINED_TABLE_STATEMENT + " ORDER BY lists.id"
    result = query(sql)
    transform_sql_table(result)
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(id)
    sql = "DELETE FROM lists WHERE id = $1"
    query(sql, id)
  end

  def update_list_name(id, list_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, list_name, id)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2)"
    query(sql, todo_name, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todos WHERE id = $1 AND list_id = $2"
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3"
    query(sql, new_status, todo_id, list_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1"
    query(sql, list_id)
  end

  private

  def query(statement, *params)
    @logger.info "\n#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def transform_sql_table(table)
    table.each_with_object([]) do |tuple, memo|
      todo =     { id: tuple["todo_id"].to_i,
                   name: tuple["todo_name"],
                   completed: tuple["completed"] == "t" }
      current_list = memo.find { |hash| hash[:id] == tuple["list_id"].to_i }

      if current_list
        current_list[:todos] << todo
      elsif tuple["todo_id"]
        memo << { id: tuple["list_id"].to_i,
                  name: tuple["list_name"],
                  todos: [todo] }
      else
        memo << { id: tuple["list_id"].to_i,
                  name: tuple["list_name"],
                  todos: [] }
      end
    end
  end
end
