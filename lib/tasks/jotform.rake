namespace :jotform do
  desc 'Create a Jotform webhook connection for a store. STORE=<code or prefixed id> FORM_ID=<jotform form id> [NAME=...] [HOST=https://...]'
  task connect: :environment do
    store_ref = ENV.fetch('STORE') { abort 'STORE is required (store code or prefixed id, e.g. store_UkLWZg9DAJ)' }
    store = Spree::Store.find_by(code: store_ref)
    store ||= Spree::Store.find_by_prefix_id(store_ref) if Spree::Store.respond_to?(:find_by_prefix_id)
    abort "Store not found: #{store_ref}" unless store

    connection = JotformConnection.create!(store: store, form_id: ENV['FORM_ID'], name: ENV['NAME'])
    host = ENV.fetch('HOST', 'https://spree-sso-production-1.onrender.com')

    puts "Store:       #{store.name} (#{store.code})"
    puts "Form ID:     #{connection.form_id.presence || '(any form)'}"
    puts "Webhook URL: #{host}#{connection.webhook_path}"
    puts 'Paste the URL into Jotform → Settings → Integrations → Webhooks.'
  end

  desc 'List Jotform connections'
  task list: :environment do
    JotformConnection.includes(:store).find_each do |c|
      puts [c.id, c.store.code, c.form_id, c.active ? 'active' : 'inactive', c.webhook_path].join("\t")
    end
  end
end
