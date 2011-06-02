using Gtk;
using Gee;
using WebKit;

public class ArtistItem : Widget {
	Label artistLabel;
}

public class BeatBox.FilterView : ScrolledWindow {
	LibraryManager lm;
	LibraryWindow lw;
	LinkedList<int> songs;
	
	VBox mainBox; // put comboboxes in top, artistBox in bottom
	
	WebView view;
	ScrolledWindow viewScroll;
	
	private string last_search;
	LinkedList<string> timeout_search;
	
	/* songs should be mutable, as we will be sorting it */
	public FilterView(LibraryManager lmm, LibraryWindow lww, LinkedList<int> ssongs) {
		lm = lmm;
		lw = lww;
		songs = ssongs;
		
		last_search = "";
		timeout_search = new LinkedList<string>();
		
		buildUI();
	}
	
	public void buildUI() {
		mainBox = new VBox(false, 0);
		view = new WebView();
		viewScroll = new ScrolledWindow(null, null);
		
        viewScroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        viewScroll.add (view);
		
		view.settings.enable_default_context_menu = false;
		
		mainBox.pack_start(viewScroll, true, true, 0);
		
		Viewport vp = new Viewport(null, null);
		vp.set_shadow_type(ShadowType.NONE);
		vp.add(mainBox);
		
		add(vp);
		
		show_all();
		
		view.navigation_requested.connect(navigationRequested);
		lw.searchField.changed.connect(searchFieldChanged);
	}
	
	public static Gtk.Alignment wrap_alignment (Gtk.Widget widget, int top, int right, int bottom, int left) {
		var alignment = new Gtk.Alignment(0.0f, 0.0f, 1.0f, 1.0f);
		alignment.top_padding = top;
		alignment.right_padding = right;
		alignment.bottom_padding = bottom;
		alignment.left_padding = left;
		
		alignment.add(widget);
		return alignment;
	}
	
	/** Goes through the hashmap and generates html. If artist,album, or genre
	 * is set, makes sure that only items that fit those filters are
	 * shown
	*/
	public void generateHTML(LinkedList<Song> toShow) {
		string html = """<!DOCTYPE html> <html lang="en"><head> 
        <style media="screen" type="text/css"> 
            body { 
                background: #fff; 
                font-family: "Droid Sans",sans-serif; 
                margin: 0px auto; 
                width: 100%; 
            } 
            #main {
				
			}
            #main li {
				float: left;
				display: inline-block;
				list-style-type: none;
			}
            #artistSection { 
                clear: both; 
                padding-right: 80px; 
                float: left; 
            }
            #artistSection h3 a {
                color: #999999;
                text-decoration: none;
            }
            #artistSection ul {
                height: auto;
                padding-bottom: 10px;
                margin-left: 0px;
                padding-left: 0px;
                margin-top: -10px;
            }
            #artistSection ul li {
                float: left;
                width: 120px;
                height: 160px;
                display: inline-block;
                list-style-type: none;
                padding-right: 10px;
                padding-bottom: 5px;
                overflow: hidden;
            }
            #artistSection ul li img {
                width: 120px;
                height: 120px;
            }
            #artistSection ul li p {
                clear: both;
                overflow: hidden;
                text-align: center;
                margin-top: 0px;
                font-size: 11px;
                margin-bottom: 0px;
            }
        </style></head><body><div id="main"><ul>""";
        
        // first sort the songs so we know they are grouped by artists, then albums
		toShow.sort((CompareFunc)songCompareFunc);
		
		string previousArtist = "";
		string previousAlbum = "";
		
		// start with the first song (instead of checking a bool every iteration which is slow)
		if(toShow.size > 0) {
			html += "<li><div id=\"artistSection\"><h3><a href=\"#\" >" + toShow.get(0).artist + "</a></h3><ul>"; //first artist section
			html += "<li><a href=\"" + toShow.get(0).album + "<seperater>" + toShow.get(0).artist + "\"><img src=\"file://" + toShow.get(0).getAlbumArtPath() + "\" /></a><p>" + ( (toShow.get(0).album == "") ? "Miscellaneous" : toShow.get(0).album) + "</p><p>2007</p><p>Rock</p></li>";
			previousAlbum = toShow.get(0).album;
			previousArtist = toShow.get(0).artist;
		}
		
		// NOTE: things to keep in mind are search, miller column, artist="", album="" cases
		foreach(Song s in toShow) {
			if(s.artist != previousArtist) {
				html += "</ul></div></li><li><div id=\"artistSection\"><h3><a href=\"#\" >" + s.artist + "</a></h3><ul>"; // end previous artist, start next
				previousArtist = s.artist;
				
				html += "<li><a href=\"" + s.album + "<seperater>" + s.artist + "\"><img src=\"file://" + s.getAlbumArtPath() + "\" /></a><p>" + ( (s.album == "") ? "Miscellaneous" : s.album) + "</p><p>2007</p><p>Rock</p></li>";
				previousAlbum = s.album;
			}
			else if(s.album != previousAlbum) {
				html += "<li><a href=\"" + s.album + "<seperater>" + s.artist + "\"><img src=\"file://" + s.getAlbumArtPath() + "\" /></a><p>" + ( (s.album == "") ? "Miscellaneous" : s.album) + "</p><p>2007</p><p>Rock</p></li>";
				previousAlbum = s.album;
			}
		}
		
		html += "</ul></div></li></ul></div></body></html>"; // finish up the last song, finish up html
		
		view.load_string(html, "text/html", "utf8", "file://");
	}
	
	public static int songCompareFunc(Song a, Song b) {
		if(a.artist.down() == b.artist.down())
			return (a.album.down() > b.album.down()) ? 1 : -1;
		else
			return (a.artist.down() > b.artist.down()) ? 1 : -1;
	}
	
	public virtual NavigationResponse navigationRequested(WebFrame frame, NetworkRequest request) {
		if(request.uri.contains("<seperater>")) {
			// switch the view
			string[] splitUp = request.uri.split("<seperater>", 0);
			
			stdout.printf("Showing song list with only songs from album " + splitUp[0] + " by " + splitUp[1] + "\n");
			
			return WebKit.NavigationResponse.IGNORE;
		}
		
		return WebKit.NavigationResponse.ACCEPT;
	}
	
	public virtual void searchFieldChanged() {
		if(/*is_current_view && */lw.searchField.get_text().length != 1) {
			timeout_search.offer_head(lw.searchField.get_text().down());
			Timeout.add(100, () => {
				string to_search = timeout_search.poll_tail();
				
				var toSearch = new LinkedList<Song>();
				foreach(int id in lm.songs_from_search(to_search, songs)) {
					toSearch.add(lm.song_from_id(id));
				}
					
				generateHTML(toSearch);
				
				return false;
			});
		}
	}
	
}