require 'discordrb'

CHECK_MARK = "\u2705"
START = "\u23EE"
FINISH = "\u23ED"
FORWARD = "\u25B6"
BACK = "\u25C0"
SAVE = "\u{1F4BE}"

PAGE_SIZE = 1

class Bot

  def self.paginated(bot, event, title, description, array)
    current_index = 0
    message = event.send_embed('', nil) do |embed|
      embed.title = title
      embed.description = description
      array[0..PAGE_SIZE - 1].map { |post| embed.add_field(name: post[:name], value: post[:value], inline: false) }
    end
    if array.length > PAGE_SIZE
      message.react START
      message.react BACK
      message.react FORWARD
      message.react FINISH
      groups = array.each_slice(PAGE_SIZE).to_a
      bot.add_await!(Discordrb::Events::ReactionAddEvent, message: message, timeout: 150) do |reaction_event|
        case reaction_event.emoji.name
          when START
            current_index = 0
            show_index(message, title, description, groups[current_index])
          when FINISH
            current_index = groups.length - 1
            show_index(message, title, description, groups[current_index])
          when FORWARD
            unless groups.length - 1 == current_index
              current_index += 1
              show_index(message, title, description, groups[current_index])
            end
          when BACK
            unless current_index == 0
              current_index -= 1
              show_index(message, title, description, groups[current_index])
            end
        end
        message.delete_reaction(reaction_event.user, reaction_event.emoji.name) if (reaction_event.channel.type != Discordrb::Channel::TYPES[:dm])
        false
      end
      message.delete_all_reactions
    end
  end
  
  def self.show_index(message, title, description, fields)
    embed = Discordrb::Webhooks::Embed.new
    embed.title = title
    embed.description = description
    fields.map { |post| embed.add_field(name: post[:name], value: post[:value], inline: false) }
    message.edit('', embed)
  end
  
  def self.run
    token = ENV['DISCORD_TOKEN'] || Config.value(:discord_token)
    bot = Discordrb::Commands::CommandBot.new token: token, prefix: '!'

    bot.command :topic do |event, *args|
      pu = File.readlines('config/pu', chomp: true) - ['e', 'pi', 'li', 'la', 'en'] + args
      pu.sample(3).join(' ')
    end

    bot.command :list do |event, *args|
      discord_id = args.try(:first) || event.author.id
      discord_id = discord_id.to_s.gsub(/[<>@!]/, '').to_i.to_s # the easiest way to extract id from the mention
      user = User.find_by(discord_id: discord_id)
      
      user_posts = []
      Post.where(user: user).each do |user_post|
        user_posts << { name: "#{user_post.id.to_s} #{user_post.name}", value: user_post.lines.first.content || "..." }
      end
      who = event.user.id == user.discord_id ? "You don't" : "<@!#{user.discord_id}> doesn't"
      return "#{who} have any posts yet" if user_posts.length == 0
      paginated(bot, event, "<@!#{user.discord_id}>'s Posts", "You can see the full posts with `!show <id>` and delete with `!delete post <id>`", user_posts)
    end

    bot.command :start do |event, *args|
      "This only works in private messages with me, sorry!"
    end

    bot.command :show do |event, *args|
      if args.length != 1
        event << "You need to specify id of the post you want to see"
        event << "`!show <id>`"
        return nil
      end
      post = Post.find_by(id: args[0])
      lines = []
      post.lines.each do |line|
        lines << { name: line.id, value: line.content }
      end
      return "This post doesn't exist" if lines.length == 0
      paginated(bot, event, "#{post.id} #{post.name}", post.user.discord_id == event.user.id || Config.value(:admins).include?(event.user.id) ? "You can delete this post with `!delete post #{post.id}`" : "", lines)
    end

    bot.command :delete do |event, *args|
      p args
      if args.length != 2
        event << "You need to specify type and id of the object to remove"
        event << "`!delete [line|post] <id>`"
        return nil
      end
      case args[0]
        when "line"
          line = Line.find_by(id: args[1])
          if line
            if line.user.discord_id == event.user.id || Config.value(:admins).include?(event.user.id)
              line.destroy
              "Successfully removed the line"
            else
              "You don't have permissions to remove this"
            end
          else
            "No such line \"#{args[1]}\""
          end
        when "post"
          post = Post.find_by(id: args[1])
          if post
            if post.user.discord_id == event.user.id || Config.value(:admins).include?(event.user.id)
              Line.where(post: post).destroy_all
              post.destroy
              "Successfully removed the post"
            else
              "You don't have permissions to remove this"
            end
          else
            "No such post \"#{args[1]}\""
          end
      end
    end

    bot.pm do |event|
      user = User.find_or_create_by(discord_id: event.author.id)
      unless user.accepted_license
        message = event.respond "You can't use this bot, unless you accept that all of the things you do to interact with this bot will be licensed under the terms of CC0 as specified in https://creativecommons.org/share-your-work/public-domain/cc0/. Reacting with the checkmark marks your aproval."
        message.react CHECK_MARK
        bot.add_await!(Discordrb::Events::ReactionAddEvent, message: message, emoji: CHECK_MARK, timeout: 300) do |_reaction_event|
          user.accepted_license = true
          user.save
          event.respond "Let's do this! Use !start (with optional title) to start and !end to finalize."
        end
        message.delete
        event.respond "If you ever change your mind, just write me here, I will be waiting!"
        nil
      end
      if event.content.start_with?('!start')
        title = event.content.split(' ')[1..-1].join(' ')
        post = Post.new(name: title, user: user)
        event.respond "Starting recording \"#{post.name || post.id}\"! Talk to your heart's content, and remember to use !end after you are done. I will react with #{SAVE} to everything I have saved. If you need inspiration, use !topic"
        event.user.await! do |post_event|
          if post_event.content.start_with?('!end')
            post.save
            post_event.respond "Cool! Post \"#{post.name || post.id}\" was saved. You can see all of your posts in !list"
            true
          elsif post_event.content.start_with?('!topic')
            bot.execute_command(:topic, post_event, post_event.content.split(' ')[1..-1])
            false
          else
            Line.new(post: post, content: post_event.content).save
            post_event.message.react SAVE
            false
          end
        end
      end
    end
    bot.run
  end
end
