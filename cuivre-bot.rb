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

bot = Discordrb::Commands::CommandBot.new token: config['token'], client_id: config['client_id'], prefix: config['prefix']

def update_ressource(db, username, ressource, operator, value)

  #Select previous value in db
  previous_value = nil
  db.execute( "select value from ressources where username=? and ressourcename=?", username, ressource ) do |row|
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
    db.execute("insert into ressources(username,ressourcename,value) values ( ?, ?, ? )", username, ressource, current_value)

  elsif operator == '=' and value.to_i == 0 #delete entry
    db.execute("delete from ressources where username=? and ressourcename=?", username, ressource)

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
    db.execute("update ressources set value=? where username=? and ressourcename=?", current_value, username, ressource)
  end

  return current_value
end

#Add a ressource
bot.command(:set, description: "Set a ressource.", usage: "set <ressource> +-= valeur", min_args: 1, max_args: 3) do |event|

  r = event.text.match /^#{config['prefix']}set ([a-z]*) *([=+-]) *([0-9]*)$/

  if r.nil?
    event.respond "Try Again"
    return
  end

  ressource = r[1]
  operator = r[2]
  value = r[3]

  #Check if ressource is allowed
  if !config['ressources'].include? ressource
    event.respond "Ressource #{ressource} not allowed"
    return
  end

  current_value = update_ressource(db, event.user.name, ressource, operator, value)


  #p "#{ressource} is now #{current_value} (+#{value})"

  event.respond "#{ressource} is now #{current_value} (+#{value}) for #{event.user.name}"
end

#Get a ressource sum value
bot.command(:get, description: "Get a ressource.", usage: "get <ressource>", min_args: 1, max_args: 1) do |event|

  r = event.text.match /^#{config['prefix']}get *([a-z]*)$/
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

bot.command(:ressources, description: "Get total ressources.") do |event|
  ressources = []
  ret = ""

  #Get all ressources names
  db.execute( "select distinct ressourcename from ressources order by ressourcename" ) do |row|
    ressources << row[0];
  end

  #Get values for each
  ressources.each do |r|
    db.execute( "select sum(value) from ressources where ressourcename = ?", r ) do |row|
      ret = ret + "*#{r}*: #{row[0]}\n"
    end
  end

  event.respond ret
end

#List all ressources for all users
bot.command(:details, description: "Get all ressources for each users.") do |event|
  ret = ""
  db.execute( "select ressourcename,username,value from ressources order by ressourcename" ) do |row|
    ret = ret + "*#{row[0]}* #{row[1]}: #{row[2]}\n"
  end
  event.respond ret
end

#List allowed ressources
bot.command(:list, description: "list allowed ressources.") do |event|
  ret = ""
  event.respond config['ressources'].sort.join("\n")
end

#Force set for a user
bot.command(:adminset, description: "Set a ressource.", usage: "adminset <user> <ressource> +-= valeur", min_args: 1, max_args: 3) do |event|
  r = event.text.match /^#{config['prefix']}adminset ([a-zA-Z0-9]*) ([a-zA-Z0-9 ()-]*) ([a-z]*) *([=+-]) *([0-9]*)$/

  if r.nil?
    event.respond "Try Again"
    return
  end

  password = r[1]
  username = r[2]
  ressource = r[3]
  operator = r[4]
  value = r[5]

  #Check password
  if config['admin_password'] != password
    event.respond "Bye"
    return
  end

  #Check if channel is private
  if !event.channel.private?
    event.respond "This must be private bro !"
    return
  end

  #Check if ressource is allowed
  if !config['ressources'].include? ressource
    event.respond "Ressource #{ressource} not allowed"
    return
  end

  current_value = update_ressource(db, username, ressource, operator, value)

  event.respond "#{ressource} is now #{current_value} (+#{value}) for #{username}"
end

bot.run
