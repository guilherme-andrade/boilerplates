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


  file 'app/javascript/src/vendor/pwa.js', <<-CODE
import ProgressiveWebApp from 'pwa-rails';
document.addEventListener('turbolinks:load', () => {
  const progressiveWebApp = new ProgressiveWebApp();
})
  CODE
end


file 'Gemfile', <<-CODE
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/\#{repo}.git" }
CODE

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
  gem 'guard-livereload'
  gem 'listen', '~> 3.2'
  gem 'rack-livereload'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'spring'
  gem 'web-console', '>= 3.3.0'
end

run 'bundle install'

environment <<-CODE
config.generators do |generate|
  generate.helper false
  generate.assets false
  generate.view_specs false
end
CODE

rails_command 'active_storage:install'
rails_command 'webpacker:install'
rails_command 'webpacker:install:stimulus'
rails_command 'stimulus_reflex:install'

run 'yarn add bootstrap@^5.0.0-alpha1 bootstrap-icons animate.css axios trix popper.js prismjs resolve-url-loader'

run "yarn install"

file "config/webpack/environment.js", <<-CODE
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

file 'app/views/application/_head.html.erb', <<-CODE
<head>
  <title>Sheen</title>
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
  <%= action_cable_meta_tag %>
  <%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload' %>
  <%= stylesheet_pack_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
</head>
CODE

file 'app/views/application/_navbar.html.erb', <<-CODE
<nav class="navbar navbar-dark w-100">
  <div class="container">
    <%= link_to root_url, class: 'navbar-brand' do %>
      Sheen
    <% end %>
    <ul class="navbar-nav flex-row">
      <li class="nav-item ml-5">
        <%= link_to 'link', '', class: 'nav-link' %>
      </li>
      <li class="nav-item ml-5">
        <%= link_to 'link', '', class: 'nav-link' %>
      </li>
      <li class="nav-item ml-5">
        <%= link_to 'link', '', class: 'nav-link font-weight-bold' %>
      </li>
    </ul>
  </div>
</nav>
CODE

file 'app/views/layouts/application.html.erb', <<-CODE
<!DOCTYPE html>
<html>
  <%= render 'head' %>

  <body>
    <%= render 'navbar' %>
    <%= yield %>
  </body>
</html>
CODE


run %Q{ curl -O https://raw.githubusercontent.com/guilherme-andrade/boilerplates/master/sheen/javascript.zip }
run %Q{ unzip javascript.zip -d app }
run %Q{ rm javascript.zip }

generate :controller, "static home"
route "root to: 'static#home'"

add_users if yes?('Add Users?')
pwa if yes?('Progressive Web App (PWA)?')

after_bundle do
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
  run "hub create" if yes?('Create Repository?')
  git push: 'origin master'
end

