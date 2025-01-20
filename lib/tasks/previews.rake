namespace :previews do
  desc 'Generate and upload missing preview images'
  task generate_all: :environment do
    coordinator_class = PreviewService::Coordinator
    aws_service = AwsService.new

    # Find all parties without previews
    parties = Party.where(preview_state: ['pending', 'failed', nil])
    total = parties.count

    puts "Found #{total} parties needing preview generation"

    parties.find_each.with_index(1) do |party, index|
      puts "[#{index}/#{total}] Processing party #{party.shortcode}..."

      begin
        coordinator = coordinator_class.new(party)
        temp_file = Tempfile.new(['preview', '.png'])

        # Create preview image
        image = coordinator.create_preview_image
        image.write(temp_file.path)

        # Upload to S3
        key = "previews/#{party.shortcode}.png"
        File.open(temp_file.path, 'rb') do |file|
          aws_service.s3_client.put_object(
            bucket: aws_service.bucket,
            key: key,
            body: file,
            content_type: 'image/png',
            acl: 'private'
          )
        end

        # Update party state
        party.update!(
          preview_state: :generated,
          preview_s3_key: key,
          preview_generated_at: Time.current
        )

        puts "  ✓ Preview generated and uploaded to S3"
      rescue => e
        puts "  ✗ Error: #{e.message}"
      ensure
        temp_file&.close
        temp_file&.unlink
      end
    end

    puts "\nPreview generation complete"
  end

  desc 'Regenerate all preview images'
  task regenerate_all: :environment do
    coordinator_class = PreviewService::Coordinator
    aws_service = AwsService.new

    parties = Party.all
    total = parties.count

    puts "Found #{total} parties to regenerate"

    parties.find_each.with_index(1) do |party, index|
      puts "[#{index}/#{total}] Processing party #{party.shortcode}..."

      begin
        coordinator = coordinator_class.new(party)
        temp_file = Tempfile.new(['preview', '.png'])

        # Create preview image
        image = coordinator.create_preview_image
        image.write(temp_file.path)

        # Upload to S3
        key = "previews/#{party.shortcode}.png"
        File.open(temp_file.path, 'rb') do |file|
          aws_service.s3_client.put_object(
            bucket: aws_service.bucket,
            key: key,
            body: file,
            content_type: 'image/png',
            acl: 'private'
          )
        end

        # Update party state
        party.update!(
          preview_state: :generated,
          preview_s3_key: key,
          preview_generated_at: Time.current
        )

        puts "  ✓ Preview regenerated and uploaded to S3"
      rescue => e
        puts "  ✗ Error: #{e.message}"
      ensure
        temp_file&.close
        temp_file&.unlink
      end
    end

    puts "\nPreview regeneration complete"
  end
end
