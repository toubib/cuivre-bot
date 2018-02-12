require 'discordrb'
require 'sqlite3'
require 'yaml'

config = YAML.load_file('cuivre.yml')

db = SQLite3::Database.new "cuivre.db"

# Create a table
rows = db.execute <<-SQL
  create table if not exists ressources (
    username varchar(100),
    ressourcename varchar(100),
    value int
  );
SQL

bot = Discordrb::Bot.new token: config['token'], client_id: config['client_id']

#Add a ressource
ressource_update_regex=/^([a-z]*) *([=+-]) *([0-9]*)$/
bot.message(contains: ressource_update_regex) do |event|
  if r = event.text.match(ressource_update_regex)
    ressource = r[1]
    operator = r[2]
    value = r[3]

    #Select previous value in db
    previous_value = nil
    db.execute( "select value from ressources where username=? and ressourcename=?", event.user.name, ressource ) do |row|
      previous_value = row[0]
    end

    if previous_value.nil? #first call
      case operator
      when '=', '+'
        current_value = value.to_i
      when '-'
        current_value = 0
      end
      #p ("insert #{current_value}")
      db.execute("insert into ressources(username,ressourcename,value) values ( ?, ?, ? )", event.user.name, ressource, current_value)

    elsif operator == '=' and value.to_i == 0 #delete entry
      db.execute("delete from ressources where username=? and ressourcename=?", event.user.name, ressource)

    else #update
      case operator
      when '='
        current_value = value.to_i
      when '+'
        current_value = previous_value.to_i + value.to_i
      when '-'
        current_value = previous_value.to_i - value.to_i
        current_value = 0 if current_value < 0
      end
      #p ("update to #{current_value}")
      db.execute("update ressources set value=? where username=? and ressourcename=?", current_value, event.user.name, ressource)
    end

    #p "#{ressource} is now #{current_value} (+#{value})"

    event.respond "#{ressource} is now #{current_value} (+#{value}) for #{event.user.name}"
  else
    event.respond "Try Again"
  end
end

#Get a ressource sum value
get_ressource_regex=/^get  *([a-z]*)$/
bot.message(contains: get_ressource_regex) do |event|
  r = event.text.match(get_ressource_regex)
  if r.nil?
    event.respond "Try Again"
    return
  end

  ressource = r[1]
  ret = ""

  #Get value for ressource
  db.execute( "select sum(value) from ressources where ressourcename = ?", ressource ) do |row|
    ret = ret + "#{ressource}: #{row[0]}\n"
  end

  event.respond ret
end

bot.message(content: 'get ressources') do |event|
  ressources = []
  ret = ""

  #Get all ressources names
  db.execute( "select distinct ressourcename from ressources order by ressourcename" ) do |row|
    ressources << row[0];
  end

  #Get values for each
  ressources.each do |r|
    db.execute( "select sum(value) from ressources where ressourcename = ?", r ) do |row|
      ret = ret + "#{r}: #{row[0]}\n"
    end
  end

  event.respond ret
end

#List all ressources for all users
bot.message(content: 'get all') do |event|
  ret = ""
  db.execute( "select ressourcename,username,value from ressources order by ressourcename" ) do |row|
    ret = ret + "#{row[0]} #{row[1]}: #{row[2]}\n"
  end
  event.respond ret
end

#Print help
bot.message(content: 'help') do |event|
  help =  "Ajouter une ressource:\n"
  help += "  <ressource> = valeur\n"
  help += "  <ressource> + valeur\n"
  help += "  <ressource> - valeur\n"
  help += "\n"
  help += "Supprimer une ressource:\n"
  help += "  <ressource> = 0\n"
  help += "\n"
  help += "Lister une ressource:\n"
  help += "  get <ressource>\n"
  help += "\n"
  help += "Lister toutes les ressources disponibles:\n"
  help += "  get ressources\n"
  help += "\n"
  help += "Lister le detail de chacun:\n"
  help += "  get all\n"
  help += "\n"
  help += "Liste des ressources autorisées:\n"
  help += "\n"

  event.respond help
end

bot.run
