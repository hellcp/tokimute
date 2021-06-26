# tokimute
Conversational bot

## Set up instructions

Install ruby, ruby development files, bundler, make and gcc c++ compiler, and run:
```sh
cp config/config.sample.yml config/config.yml
editor config/config.yml # Modify the config to fit your needs
# You can also optionally use `editor db/config.yml` to modify db configuration
bundler install
bundler exec rake db:setup
bundler exec rake db:migrate # Add `db=production` to use migrations on the production database
bundler exec bin/tokimute # This starts the bot
```
