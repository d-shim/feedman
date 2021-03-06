#require 'feedzirra'
require 'feedjira'
require 'open-uri'
require 'nokogiri'
require 'rss'

namespace :fetch_feed do
  include ActiveModel::ForbiddenAttributesProtection

  desc "fetch RSS feed"

    task :fetch => :environment do
      p Time.now
      p "Start Fetch:Feed Rake Task"
      print("\n")

      Feed.all.each do |feed|

        if feed.url != nil && (feed.feed_url == "" || feed.feed_url == nil)
          feed_url = nil
          site_url = feed.url
          p site_url
          begin
            doc = Nokogiri::HTML(open(site_url),nil,'utf-8')
          rescue Exception => e
            p "URL Analyze(Nokogiri) Error" + feed.url
            next
          end

          doc.css('link').each do |link|

            if link['type'] == 'application/rss+xml' && link['rel'] == 'alternate' && link['href'].include?("/comment/") == false && link['href'].include?("/comments/") == false
              href = link['href']
              feed_url = URI.join(site_url, href)
              p "feed_url #{feed_url}"
              break

            elsif link['type'] == 'application/atom+xml' && link['rel'] == 'alternate' && link['href'].include?("/comment/") == false && link['href'].include?("/comments/") == false
              href = link['href']
              feed_url = URI.join(site_url, href)
              p "atom_url #{feed_url}"
              break

            end
          end

        elsif feed.feed_url != nil
          feed_url = feed.feed_url
          p "rss_url #{feed_url}"

        end

          if false && feed.last_modified != nil
            #parsedFeed = Feedzirra::Feed.fetch_and_parse "#{feed_url}", :if_modified_since => feed.last_modified
            parsedFeed = Feedjira::Feed.fetch_and_parse "#{feed_url}", :if_modified_since => feed.last_modified
          else
            parsedFeed = Feedjira::Feed.fetch_and_parse "#{feed_url}"
          end

          if !parsedFeed || parsedFeed.instance_of?(Fixnum)
            p 'Skipped '+feed.url
            next
          end

          # Update feed meta data
          if "#{feed_url}" != nil  then
            feed.title = parsedFeed.title
            feed.last_modified = parsedFeed.last_modified
            feed.feed_url = "#{feed_url}"
            if feed.url == nil
              feed.url = parsedFeed.url
            end
          end
          feed.save

          # DBに保存されている最新のエントリを取得
          latest_entry = Entry.where(:feed_id => feed.id).order('created_at DESC').first
          #p "latest_entry #{latest_entry}"
          ## 取得したFeedを更新日時の昇順に並べ替え
          # 取得したFeedを更新日時の降順に並べ替え
          #p parsedFeed.entries
          #tmp = parsedFeed.entries
          #p tmp
          #if parsedFeed.entries.published != nil
          parsedFeed.entries.delete_if { |tmpentries| tmpentries.published == nil }
          if parsedFeed.entries.length > 2
          #if parsedFeed.entries[0][1].nil? == false
            #begin
              parsedFeed_entries_tmp = parsedFeed.entries.sort{|aa, bb|
              #(-1) * (aa.published <=> bb.published)
            #if aa.published != bb.published
            #if aa.published != nil && bb.published != nil
                aa.published <=> bb.published
            #end
              }
             #rescue ArgumentError
          else
        #  next
            parsedFeed_entries_tmp = parsedFeed.entries
            #end
          end
          #end
          # 降順に並べ替え
          begin
            parsedFeed_entries = parsedFeed_entries_tmp.reverse
          rescue NoMethodError
            next
          end

          # latest_entryの更新日時とparsedFeed_entriesの更新日時を比較して
          # parsedFeed_entriesの更新日時が大きければupdatedEntriesへ格納
          if latest_entry != nil
            updatedEntries = parsedFeed_entries.take_while {
              |e| e.published > latest_entry.published_at
            }
          #else
          elsif latest_entry == nil
            updatedEntries = parsedFeed_entries
          else
            next
          end

          # Save entries
          updatedEntries.reverse.each do |feed_entry|

            if feed_entry.url.nil? == false && feed_entry.url.include?("#comment-") == false
              p 'Add => ' + feed_entry.url

              entry = Entry.new({
                :feed_title   => feed.title,
                :title        => feed_entry.title,
                :url          => feed_entry.url,
                :summary      => (feed_entry.summary || feed_entry.content || '').gsub(/<.+?>/m, '').slice(0, 255),
                :published_at => feed_entry.published,
                :feed_id      => feed.id
                #:read         => 'f'
              })
             entry.save
            else
              next
            end

          end

      end
      print("\n")
      p "Finished Rake Task"

    end

end
