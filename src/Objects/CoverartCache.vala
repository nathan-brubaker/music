// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2012 Noise Developers (http://launchpad.net/noise)
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
 *
 * The Noise authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Noise. This permission is above and beyond the permissions granted
 * by the GPL license by which Noise is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 *
 * Authored by: Victor Eduardo <victoreduardm@gmail.com>
 */

/**
 * Stores and fetches album-art images
 */
public class Noise.CoverartCache : MediaArtCache {

    private static CoverartCache? _instance = null;
    public static CoverartCache instance {
        get {
            if (_instance == null)
                _instance = new CoverartCache ();
            return _instance;
        }
    }

    private Gdk.Pixbuf default_image;


    public CoverartCache () {
        assert (_instance == null);

        base ("album-art");

        bool dummy;
        default_image = filter_func (Icons.DEFAULT_ALBUM_ART.render (null), out dummy);
    }


    // add a shadow to every image
    protected override Gdk.Pixbuf? filter_func (Gdk.Pixbuf pix, out bool apply_to_file) {
        apply_to_file = false;
        return PixbufUtils.get_pixbuf_shadow (pix, Icons.ALBUM_VIEW_IMAGE_SIZE);
    }


    protected override string get_key (Media m) {
        string album_name = m.album;
        string artist_name = m.album_artist;

        if (artist_name == "")
            artist_name = m.artist;

        return @"$artist_name-$album_name";
    }


    public Gdk.Pixbuf get_cover (Media m) {
        var image = get_image (m, false);
        return image ?? default_image;
    }


    public async void fetch_all_cover_art_async (Gee.Collection<Media> media) {
        yield fetch_folder_images_async (media);
        yield load_for_media_async (media);
    }


    public async void load_for_media_async (Gee.Collection<Media> media) {
        SourceFunc callback = load_for_media_async.callback;

        try {
            new Thread<void*>.try (null, () => {
                load_for_media (media);

                Idle.add ((owned)callback);
                return null;
            });
        } catch (Error err) {
            warning ("Could not create thread to fetch all cover art: %s", err.message);
        }

        yield;
    }


    public void load_for_media (Gee.Collection<Media> media) {
        debug ("READING CACHED COVERART");

        var used_keys_set = new Gee.HashSet<string> ();

        foreach (var m in media) {
            string key = get_key (m);

            if (!used_keys_set.contains (key) && !has_image (m)) {
                debug ("Getting [%s]", key);

                // Pass true to lookup_file in order to fetch the images for the first time
                get_image (m, true);

                used_keys_set.add (key);
            }
        }

        debug ("FINISHED LOADING CACHED COVERART");

        queue_notify ();
    }


    public async void fetch_folder_images_async (Gee.Collection<Media> media) {
        SourceFunc callback = fetch_folder_images_async.callback;

        try {
            new Thread<void*>.try (null, () => {
                fetch_folder_images (media);

                Idle.add ((owned)callback);
                return null;
            });
        } catch (Error err) {
            warning ("Could not create thread to fetch all cover art: %s", err.message);
        }

        yield;
    }


    /**
     * Looks up for image types in the media's directory. We look for image files
     * that follow certain name patterns, like "album.png", "folder.jpg", etc.
     */
    public void fetch_folder_images (Gee.Collection<Media> media) {
        foreach (var m in media) {
            if (!has_image (m)) {
                var art_file = lookup_folder_image_file (m);
                if (art_file != null)
                    cache_image_from_file (m, art_file);
            }
        }

        queue_notify ();
    }


    // Awesome method taken from BeatBox's FileOperator.vala (adapted to use Noise's internal API)
    private static File? lookup_folder_image_file (Media m) {
        File? rv = null, media_file = m.file;

        if (!media_file.query_exists ())
            return rv;

        var album_folder = media_file.get_parent ();

        if (album_folder == null)
            return rv;

        // Don't consider generic image names if the album folder doesn't contain the name of
        // the media's album. This is probably the simpler way to prevent considering images
        // from folders that contain multiple unrelated tracks.
        bool generic_folder = !album_folder.get_path ().contains (m.album);

        string[] image_types = { "jpg", "jpeg", "png" };
        Gee.Collection<File> image_files;
        FileUtils.enumerate_files (album_folder, image_types, false, out image_files);

        // Choose an image based on priorities.
        foreach (var file in image_files) {
            string file_path = file.get_path ().down ();

            if (generic_folder) {
                if (m.album in file_path) {
                    rv = file;
                    break;
                }

                continue;
            }


            if ("folder" in file_path) {
                rv = file;
                break;
            }

            if ("cover" in file_path) {
                rv = file;
            } else if (rv != null) {
                if (!("cover" in rv.get_path ()) && "album" in file_path)
                    rv = file;
                else if (!("album" in rv.get_path ()) && "front" in file_path)
                    rv = file;
                else if (!("front" in rv.get_path ()) && m.album in file_path)
                    rv = file;
            }
        }

        return rv;
    }
}