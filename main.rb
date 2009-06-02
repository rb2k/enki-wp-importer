require "rubygems"
require "sequel"

puts "Starting Import"
DB_WP = Sequel.connect('mysql://user:pass@localhost/database_name')
DB_ENKI = Sequel.connect('sqlite:///path/to/db/file.sqlite3')
WP_PREFIX = "wp_123abc"


#preparing post import
ENKI_POSTS = DB_ENKI[:posts]
WP_POSTS = DB_WP.from(:"#{WP_PREFIX}_posts").where(:post_type => "post", :post_status => "publish").order(:ID)
WP_POST_AMOUNT = WP_POSTS.count

#preparing pages import
ENKI_PAGES = DB_ENKI[:pages]
WP_PAGES = DB_WP.from(:"#{WP_PREFIX}_posts").where(:post_type => "page", :post_status => "publish").order(:ID)
WP_PAGES_AMOUNT = WP_PAGES.count

#preparing comment import
ENKI_COMMENTS = DB_ENKI[:comments]
WP_COMMENTS = DB_WP.from(:"#{WP_PREFIX}_comments").where(:comment_approved => 1)
WP_COMMENTS_AMOUNT = WP_PAGES.count

#Transfering the posts + related comments
puts "Transfering posts and comments"

comment_counter = 0
WP_POSTS.all.each_with_index do |row,index|
    post_ID = index
    post_original_ID = row[:ID]
    post_date = row[:post_date]
    post_title = row[:post_title].to_s
    post_content = row[:post_content].to_s
    post_created_at= row[:post_date]
    post_modified = row[:post_modified]
    comment_count = row[:comment_count]
    post_name = row[:post_name]


    ENKI_POSTS.insert(  :id => post_ID, :title => post_title, :body_html => post_content, :active => "t",
                        :body => post_content, :created_at => post_created_at,
                        :published_at => post_created_at, :updated_at => post_modified, :edited_at => post_modified,
                        :approved_comments_count => comment_count, :slug => post_name
                        )
     puts "Transferred #{post_name} (#{index + 1} / #{WP_POST_AMOUNT})"
     print "Comments: "
     WP_COMMENTS.where(:comment_post_ID => post_original_ID).order_by(:comment_ID).each do |comment|

          ENKI_COMMENTS.insert(
          :id => comment_counter,
          :post_id => post_ID,
          :author => comment[:comment_author],
          :author_url => comment[:comment_author_url],
          :author_email => comment[:comment_author_email],
          :body => comment[:comment_content],
          :body_html => comment[:comment_content],
          :created_at => comment[:comment_date],
          :updated_at => comment[:comment_date]
          )
        print "#{comment_counter} | "
        comment_counter+=1
      end
print " \n"


print "Tags: "
DB_WP.fetch("SELECT name, id FROM #{WP_PREFIX}_terms t, #{WP_PREFIX}_posts p, #{WP_PREFIX}_term_relationships r, #{WP_PREFIX}_term_taxonomy tt WHERE p.post_status='publish' AND tt.taxonomy = 'post_tag' AND p.id=r.object_id AND r.term_taxonomy_id=tt.term_taxonomy_id AND tt.term_id = t.term_id AND p.id=#{post_original_ID}") do |tag_row|

        print tag_row[:name]

        #check if there's already a tag with that name
        if (DB_ENKI[:tags].filter(:name => tag_row[:name]).count==0)
                print "[NEW]"
                DB_ENKI[:tags].insert(:name => tag_row[:name])
        end
        #inserting the newly found tag into the taggings table
        my_tag_id = DB_ENKI[:tags].filter(:name => tag_row[:name]).first[:id]
        DB_ENKI[:taggings].insert(:tag_id => my_tag_id, :taggable_id => index)
        print " | "
end
print "\n"


end

puts "Transfering pages"
WP_PAGES.all.each_with_index do |row, index|
        page_ID = index
        page_date = row[:post_date]
        page_title = row[:post_title].to_s
        page_content = row[:post_content].to_s
        page_created_at= row[:post_date]
        page_modified = row[:post_modified]
        page_name = row[:post_name]
        ENKI_PAGES.insert(  :id => page_ID, :title => page_title, :body_html => page_content, :body => page_content, :slug=> page_title,
                            :created_at => page_created_at,:updated_at => page_modified
                        )
     puts "Transferred #{page_name} (#{index + 1} / #{WP_PAGES_AMOUNT})"


end

