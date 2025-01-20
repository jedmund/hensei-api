Rails.application.config.assets.precompile += %w( .otf )

# Ensure fonts directory exists in production
fonts_dir = Rails.root.join('public', 'assets', 'fonts')
FileUtils.mkdir_p(fonts_dir) unless File.directory?(fonts_dir)

# Copy fonts to public directory in production
if Rails.env.production?
  Dir[Rails.root.join('app', 'assets', 'fonts', '*')].each do |font|
    FileUtils.cp(font, fonts_dir) if File.file?(font)
  end
end
