def add_users
  gem 'devise'

  rails_command "generate devise:install"
  environment %Q{ config.action_mailer.default_url_options = { host: 'localhost', port: 3000 } }, env: :development

  generate :devise, "user"

  file 'app/reflexes/application_reflex.rb', <<-CODE
class ApplicationReflex < StimulusReflex::Reflex
  delegate :current_user, to: :connection
end
  CODE

  file 'app/channels/application_cable/connection.rb ', <<-CODE
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = env["warden"].user || reject_unauthorized_connection
    end
  end
end
  CODE
end

def pwa
  gem 'pwa'
  run 'yarn add pwa-rails'

  rails_command 'g mozaic:install'
  rails_command 'g pwa:install'
  rails_command 'g pwa:app -n "App"'

  route %Q{ mount Pwa::Engine, at: '' }

  initializer 'pwa.rb', <<-CODE
Pwa.configure do |config|
  config.define_app 'App'
end
  CODE

run %Q{ sed '8i\\\n<%= component 'pwa/manifest', url: request.base_url %>\\\n' app/views/application/_head.html.erb }

  file 'app/javascript/src/vendor/pwa.js', <<-CODE
import ProgressiveWebApp from 'pwa-rails';
document.addEventListener('turbolinks:load', () => {
  const progressiveWebApp = new ProgressiveWebApp();
})
  CODE
end

def create_repo_and_push
  run 'hub create'
  git push: 'origin master'
end

run %Q{ sed '2i\\\ngit_source(:github) { |repo| "https://github.com/\\\#{repo}.git" }\\\n' Gemfile }

gem 'bootsnap', '>= 1.4.2', require: false
gem 'cloudinary'
gem 'figaro'
gem 'image_processing', '~> 1.2'
gem 'pg', '>= 0.18', '< 2.0'
gem 'puma', '~> 4.1'
gem 'rails', '~> 6.0.3'
gem 'simple_form'
gem 'stimulus_reflex', '~> 3.2'
gem 'turbolinks', '~> 5'
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
gem 'view_component', '~> 2.13'
gem 'view_component_reflex'
gem 'webpacker', '~> 4.0'

gem_group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

gem_group :development do
  gem 'foreman'
  gem 'guard-livereload'
  gem 'listen', '~> 3.2'
  gem 'rack-livereload'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'spring'
  gem 'web-console', '>= 3.3.0'
end

run 'bundle install'

rails_command 'generate simple_form:install'
rails_command 'generate simple_form:install --bootstrap'
rails_command 'stimulus_reflex:install'
rails_command 'active_storage:install'

generate :controller, "static home"
route "root to: 'static#home'"

environment <<-CODE
config.generators do |generate|
  generate.helper false
  generate.assets false
  generate.view_specs false
end
CODE

run 'yarn add bootstrap@^5.0.0-alpha1 bootstrap-icons animate.css axios trix popper.js prismjs resolve-url-loader'

file 'config/sidekiq.yml', <<-CODE
:concurrency: 1
:timeout: 60
:verbose: true
:queues:  # Queue priority: https://github.com/mperham/sidekiq/wiki/Advanced-Options
  - default
  - mailers
CODE

file 'Procfile', <<-CODE
  web: bundle exec puma.rb -C config/puma.rb
  assets: webpack-dev-server
  worker: bundle exec sidekiq -C config/sidekiq.yml
CODE

run %Q{ sed '15i\\\nrequire "view_component/engine"\\\n' config/application.rb }

after_bundle do

  file 'config/webpack/environment.js', <<-CODE
  const { environment } = require('@rails/webpacker')
  environment.loaders.get('sass').use.splice(-1, 0, {
    loader: 'resolve-url-loader'
  });
  const nodeModulesLoader = environment.loaders.get('nodeModules');
  if (!Array.isArray(nodeModulesLoader.exclude)) {
    nodeModulesLoader.exclude =
      nodeModulesLoader.exclude == null ? [] : [nodeModulesLoader.exclude];
  }
  module.exports = environment;
  CODE

  run %Q{ curl -O https://raw.githubusercontent.com/guilherme-andrade/boilerplates/master/sheen/javascript.zip }
  run %Q{ unzip -o javascript.zip -d app }
  run %Q{ rm javascript.zip }
  run %Q{ rm -rf app/assets }

  run %Q{ curl -O https://raw.githubusercontent.com/guilherme-andrade/boilerplates/master/sheen/views.zip }
  run %Q{ unzip -o views.zip -d app }
  run %Q{ rm views.zip }

  add_users if yes?('Add Users?')
  pwa if yes?('Progressive Web App (PWA)?')

  rails_command 'db:create'
  rails_command 'db:migrate'

  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
  create_repo_and_push if yes?('Create Repository?')

  run 'foreman start'
end

