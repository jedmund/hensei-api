# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Playlist, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:playlist_parties).dependent(:destroy) }
    it { should have_many(:parties).through(:playlist_parties) }
  end

  describe 'validations' do
    let(:user) { create(:user) }

    describe 'title' do
      it 'requires a title' do
        playlist = build(:playlist, user: user, title: nil)
        expect(playlist).not_to be_valid
        expect(playlist.errors[:title]).to include("can't be blank")
      end

      it 'enforces uniqueness scoped to user' do
        create(:playlist, user: user, title: 'My Playlist')
        duplicate = build(:playlist, user: user, title: 'My Playlist')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:title]).to include('has already been taken')
      end

      it 'allows the same title for different users' do
        other_user = create(:user)
        create(:playlist, user: user, title: 'My Playlist')
        playlist = build(:playlist, user: other_user, title: 'My Playlist')
        expect(playlist).to be_valid
      end
    end

    describe 'visibility' do
      it { should allow_values(1, 2, 3).for(:visibility) }

      it 'rejects invalid visibility values' do
        playlist = build(:playlist, user: user, visibility: 0)
        expect(playlist).not_to be_valid
      end
    end

    describe 'video_url' do
      it 'accepts valid YouTube URLs' do
        valid_urls = [
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          'https://youtu.be/dQw4w9WgXcQ',
          'http://youtube.com/watch?v=abc123'
        ]
        valid_urls.each do |url|
          playlist = build(:playlist, user: user, video_url: url)
          expect(playlist).to be_valid, "Expected '#{url}' to be valid"
        end
      end

      it 'rejects invalid URLs' do
        playlist = build(:playlist, user: user, video_url: 'https://vimeo.com/12345')
        expect(playlist).not_to be_valid
        expect(playlist.errors[:video_url]).to include('must be a valid YouTube URL')
      end

      it 'allows blank video_url' do
        playlist = build(:playlist, user: user, video_url: '')
        expect(playlist).to be_valid
      end
    end
  end

  describe '#viewable_by?' do
    let(:owner) { create(:user) }
    let(:viewer) { create(:user) }

    it 'allows anyone to view a public playlist' do
      playlist = create(:playlist, user: owner, visibility: 1)
      expect(playlist.viewable_by?(nil)).to be true
      expect(playlist.viewable_by?(viewer)).to be true
    end

    it 'allows anyone to view an unlisted playlist' do
      playlist = create(:playlist, user: owner, visibility: 2)
      expect(playlist.viewable_by?(viewer)).to be true
    end

    it 'restricts private playlists to the owner' do
      playlist = create(:playlist, user: owner, visibility: 3)
      expect(playlist.viewable_by?(viewer)).to be false
      expect(playlist.viewable_by?(nil)).to be false
      expect(playlist.viewable_by?(owner)).to be true
    end
  end

  describe 'slug generation' do
    let(:user) { create(:user) }

    it 'generates a slug from the title on create' do
      playlist = create(:playlist, user: user, title: 'My Fire Team')
      expect(playlist.slug).to eq('my-fire-team')
    end

    it 'regenerates the slug when title changes' do
      playlist = create(:playlist, user: user, title: 'Old Name')
      playlist.update!(title: 'New Name')
      expect(playlist.slug).to eq('new-name')
    end

    it 'appends a counter when slug collides within the same user' do
      create(:playlist, user: user, title: 'My Playlist')
      # Force a collision by using the same parameterized title
      second = create(:playlist, user: user, title: 'My Playlist!')
      expect(second.slug).to start_with('my-playlist')
    end

    it 'generates a random slug for non-ASCII titles' do
      playlist = create(:playlist, user: user, title: '光パ編成')
      expect(playlist.slug).to be_present
      expect(playlist.slug.length).to be >= 8
    end
  end

  describe '.visible_to' do
    let(:owner) { create(:user) }
    let(:viewer) { create(:user) }

    let!(:public_playlist) { create(:playlist, user: owner, visibility: 1) }
    let!(:unlisted_playlist) { create(:playlist, user: owner, visibility: 2) }
    let!(:private_playlist) { create(:playlist, user: owner, visibility: 3) }

    it 'returns all playlists for the owner' do
      result = owner.playlists.visible_to(owner, owner)
      expect(result).to contain_exactly(public_playlist, unlisted_playlist, private_playlist)
    end

    it 'returns only public and unlisted playlists for other users' do
      result = owner.playlists.visible_to(viewer, owner)
      expect(result).to contain_exactly(public_playlist, unlisted_playlist)
    end

    it 'returns only public and unlisted playlists for anonymous users' do
      result = owner.playlists.visible_to(nil, owner)
      expect(result).to contain_exactly(public_playlist, unlisted_playlist)
    end
  end
end
