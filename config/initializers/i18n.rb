require "i18n/backend/fallbacks" 
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)

I18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
I18n.available_locales = [:en, :en_tish]
I18n.default_locale = :en
I18n.fallbacks.map(:en_tish => :en)

#I18n.fallbacks.map(en_tish: :en)
#I18n.fallbacks = [I18n.default_locale]

#puts "I18n fallback check: #{I18n.t("options.total_rounds.label", locale: :en_tish)}".red
