/*-
 * Copyright (c) 2011-2012       Scott Ringwelski <sgringwe@mtu.edu>
 *
 * Originally Written by Scott Ringwelski for BeatBox Music Player
 * BeatBox Music Player: http://www.launchpad.net/beat-box
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

using Gee;
using Gtk;

public class BeatBox.AlbumListView : Window {

	public const int WIDTH = 400;
	public const int HEIGHT = 400; 

	LibraryManager lm;
	ViewWrapper view_wrapper;

	Label album_label;
	Label artist_label;
	RatingWidget rating;
	MusicTreeView mtv;

	Gee.LinkedList<Media> media_list;

	Mutex setting_media = new Mutex ();

/*
	private const string WIDGET_STYLESHEET = """
		BeatBoxAlbumListView {
			background-image: -gtk-gradient (linear,
			                                 right bottom,
			                                 left bottom,
			                                 from (shade (#1e1e1e, 0.9)),
			                                 color-stop (0.5, shade (#1e1e1e, 1.23)),
			                                 to (shade (#1e1e1e, 0.9)));
			border-width: 0;
			border-style: none;
			border-radius: 0;
			padding: 0;
		}

		* {
			color: @selected_fg_color;
		}

		BeatBoxAlbumListView GtkTreeView {
			background-image: -gtk-gradient (linear,
			                                 right bottom,
			                                 left bottom,
			                                 from (shade (#1e1e1e, 0.9)),
			                                 color-stop (0.5, shade (#1e1e1e, 1.23)),
			                                 to (shade (#1e1e1e, 0.9)));

			-GtkTreeView-tree-line-pattern: "\001\002";
		}

		BeatBoxAlbumListView GtkTreeView row {
			border-width: 0;
			border-radius: 0;
			padding: 0;
		}

		BeatBoxAlbumListView GtkTreeView row:nth-child(even) {
			background-image: -gtk-gradient (linear,
			                                 right bottom,
			                                 left bottom,
			                                 from (shade (#1e1e1e, 0.8)),
			                                 color-stop (0.5, #1e1e1e),
			                                 to (shade (#1e1e1e, 0.8)));
		}

		BeatBoxAlbumListView GtkTreeView row:selected {
			background-image: -gtk-gradient (linear,
			                                 left top,
			                                 left bottom,
			                                 from (shade (@selected_bg_color, 1.30)),
			                                 to (shade (@selected_bg_color, 0.98)));
		}

		BeatBoxAlbumListView .close-button,
		BeatBoxAlbumListView .close-button:hover,
		BeatBoxAlbumListView .close-button:active,
		BeatBoxAlbumListView .close-button:active:hover {
			background-color: #000;
			background-image: none;

			border-width: 1px;
			border-color: #3c3b37;

			-unico-border-width: 0;
			-unico-outer-stroke-width: 0;
			-unico-inner-stroke-width: 0;
		}
	""";
*/

	public AlbumListView(AlbumView album_view) {
		this.view_wrapper = album_view.parent_view_wrapper;
		this.lm = view_wrapper.lm;

		set_transient_for(lm.lw);
		window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
		set_decorated(false);
		set_has_resize_grip(false);
		set_resizable(false);
		set_skip_taskbar_hint(true);
		this.destroy_with_parent = true;
		set_size_request(WIDTH, HEIGHT);
		set_default_size(WIDTH, HEIGHT);
/*
		// apply css styling
		var style_provider = new CssProvider();

		try  {
			style_provider.load_from_data (WIDGET_STYLESHEET, -1);
		} catch (Error e) {
			warning (e.message);
		}

		get_style_context().add_provider(style_provider, STYLE_PROVIDER_PRIORITY_FALLBACK);
		get_style_context().add_provider(style_provider, STYLE_PROVIDER_PRIORITY_THEME);
*/

		// add close button
		var close = new Gtk.Button ();

//		close.get_style_context().add_class("close-button");

//		close.get_style_context().add_provider(style_provider, STYLE_PROVIDER_PRIORITY_THEME);

		close.set_image (Icons.render_image ("gtk-close", Gtk.IconSize.MENU));

		close.hexpand = close.vexpand = false;
		close.halign = Gtk.Align.START;
		close.set_relief(Gtk.ReliefStyle.NONE);
		close.clicked.connect( () =>  { this.hide(); });

		// add album artist/album labels
		album_label = new Label("Album");
		artist_label = new Label("Artist");

		album_label.ellipsize = Pango.EllipsizeMode.END;
		artist_label.ellipsize = Pango.EllipsizeMode.END;

		album_label.set_max_width_chars (30);
		artist_label.set_max_width_chars (30);

		// Label wrapper
		var label_wrapper = new Box (Orientation.HORIZONTAL, 0);
		var label_box = new Box (Orientation.VERTICAL, 0);

		label_box.pack_start (album_label, false, true, 0);
		label_box.pack_start (artist_label, false, true, 8);

		// left and right label padding
		label_wrapper.pack_start (new Box (Orientation.VERTICAL, 0), false, false, 12);
		label_wrapper.pack_end (new Box (Orientation.VERTICAL, 0), false, false, 12);

		label_wrapper.pack_start (label_box, true, true, 0);

		// add actual list
		mtv = new MusicTreeView(view_wrapper, new TreeViewSetup(MusicTreeView.MusicColumn.TRACK, Gtk.SortType.ASCENDING, ViewWrapper.Hint.ALBUM_LIST));
//		mtv.apply_style_to_view(style_provider);
//		mtv = new MusicTreeView(view_wrapper, "Artist", SortType.ASCENDING, ViewWrapper.Hint.ALBUM_LIST, -1);
//		mtv.apply_style_to_view(style_provider);

		mtv.has_grid_lines = true;
		mtv.vexpand = true;

		var mtv_scrolled = new ScrolledWindow (null, null);
		mtv_scrolled.add (mtv);

		// add rating
		rating = new RatingWidget(get_style_context(), true, IconSize.MENU, true);
		rating.set_transparent (true);

		var all_area = new Box(Orientation.VERTICAL, 0);
		all_area.pack_start(close, false, false, 0);
		all_area.pack_start(label_wrapper, false, true, 0);
		all_area.pack_start(mtv_scrolled, true, true, 6);
		all_area.pack_start(rating, false, true, 12);

		add(all_area);

		rating.rating_changed.connect(rating_changed);
	}

	public void set_songs_from_media(Media m) {
		setting_media.lock ();

		set_title (m.album + " by " + m.album_artist);

		album_label.set_markup("<span size=\"large\" color=\"#ffffff\"><b>" + m.album.replace("&", "&amp;") + "</b></span>");
		artist_label.set_markup("<span color=\"#ffffff\"><b>" + m.album_artist.replace("&", "&amp;") + "</b></span>");

		var to_search = new LinkedList<Media>();
		// only search the media that match the search filter
		foreach (int id in view_wrapper.get_showing_media_ids ()) {
			to_search.add (lm.media_from_id(id));
		}

		Utils.fast_album_search_in_media_list (to_search, out media_list, "", m.album_artist, m.album);

		var media_table = new HashTable<int, Media>(null, null);

		int index = 0;
		foreach (var _media in media_list) {
			media_table.set (index++, _media);
		}

		mtv.set_table (media_table);

		setting_media.unlock ();

		// Set rating
		update_album_rating ();
		lm.medias_updated.connect (update_album_rating);
	}


	void update_album_rating () {
		setting_media.lock ();

		// decide rating. unless all are equal, show the lowest.
		// FIXME: Use the average rating
		int overall_rating = -1;
		foreach(var media in media_list) {
			if (media == null)
				continue;

			int media_rating = (int)media.rating;

			if(overall_rating == -1) {
				overall_rating = media_rating;
			} else if(media_rating != overall_rating) {
				if (media_rating < overall_rating)
					overall_rating = media_rating;
			}
		}

		rating.set_rating(overall_rating);

		setting_media.unlock ();
	}

	void rating_changed(int new_rating) {
		setting_media.lock ();

		var updated = new LinkedList<Media>();
		foreach(var media in media_list) {
			if (media == null)
				continue;

			media.rating = (uint)new_rating;
			updated.add(media);
		}

		setting_media.unlock ();

		lm.update_medias(updated, false, true);
	}
}


