run %Q{ sed '15 require "view_component/engine"' config/application.rb }
  run %Q{ sed -i '8i  <%= component 'pwa/manifest', url: request.base_url %>' app/views/application/_head.html.erb }
  run %Q{ sed -i '4iimport \'./rails\';' app/javascript/src/vendor/index.js }
