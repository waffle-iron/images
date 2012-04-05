source 'http://rubygems.org'

gem 'rails', '3.2.2'
gem 'blacklight', '3.3.1'
gem 'hydra-head', :git=>'git://github.com/projecthydra/hydra-head.git', :ref=>'41f10bc'# > 4.0.0.rc5 
gem 'sqlite3'

#  We will assume you're using devise in tutorials/documentation. 
# You are free to implement your own User/Authentication solution in its place.
gem 'devise'


# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
  gem 'compass-rails', '~> 1.0.0'
  gem 'compass-susy-plugin', '~> 0.9.0', :require => 'susy'
  # gem 'therubyracer'
  gem 'jquery-ui-rails'
  gem "bootstrap-sass-rails", "~> 2.0.2.2"

end

gem 'jquery-rails'
gem 'jquery.fileupload-rails'


# For testing.  You will probably want to use all of these to run the tests you write for your hydra head
group :development, :test do 
  gem 'jettywrapper'
  gem 'rspec-rails', '>=2.9.0'
  gem 'cucumber-rails', :require=>false
  gem 'factory_girl_rails'
  gem 'database_cleaner'
  gem 'capybara'
  gem 'bcrypt-ruby'
end

gem 'unicorn'
