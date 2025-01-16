# frozen_string_literal: true

module LoggingHelper
  def log_step(message)
    puts message
  end

  def log_verbose(message)
    print message if @verbose
  end

  def log_error(message)
    puts "#{message}"
  end

  def log_warning(message)
    puts "⚠️ #{message}"
  end

  def log_divider(character = '+', leading_newline = true, trailing_newlines = 1)
    output = ""
    output += "\n" if leading_newline
    output += character * 60
    output += "\n" * trailing_newlines
    log_step output
  end

  def log_header(title, character = '+', leading_newline = true)
    log_divider(character, leading_newline, 0)
    log_step title
    log_divider(character, false)
  end
end
