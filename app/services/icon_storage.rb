# frozen_string_literal: true

# Editor-uploaded icon storage. In production this writes to S3 via
# AwsService; in development/test it writes to public/<key> so files
# are served by Rails' public_file_server at /<key>.
#
# Keys are stable, slash-separated paths starting with `images/`
# (e.g. `images/difficulties/abc.png`). Read paths on the web side
# strip the leading `images/` and prepend the configured image host.
class IconStorage
  CONTENT_TYPE = 'image/png'

  def self.put(key, bytes)
    new.put(key, bytes)
  end

  def self.copy(source_key, dest_key)
    new.copy(source_key, dest_key)
  end

  def self.delete(key)
    new.delete(key)
  end

  def initialize
    @backend = Rails.env.production? ? :s3 : :local
  end

  def put(key, bytes)
    if @backend == :s3
      aws.s3_client.put_object(
        bucket: aws.bucket,
        key: key,
        body: StringIO.new(bytes),
        content_type: CONTENT_TYPE,
        acl: 'public-read'
      )
    else
      path = local_path(key)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, bytes)
    end
  end

  def copy(source_key, dest_key)
    if @backend == :s3
      aws.s3_client.copy_object(
        bucket: aws.bucket,
        copy_source: "#{aws.bucket}/#{source_key}",
        key: dest_key,
        acl: 'public-read',
        metadata_directive: 'COPY'
      )
    else
      src = local_path(source_key)
      dest = local_path(dest_key)
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(src, dest)
    end
  end

  def delete(key)
    if @backend == :s3
      aws.s3_client.delete_object(bucket: aws.bucket, key: key)
    else
      path = local_path(key)
      File.delete(path) if File.exist?(path)
    end
  end

  private

  def aws
    @aws ||= AwsService.new
  end

  def local_path(key)
    Rails.root.join('public', key)
  end
end
