// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class KeyboardLayoutView : AbstractInstallerView {
    public signal void next_step ();

    private Gtk.ListBox input_language_list_box;

    construct {
        var image = new Gtk.Image.from_icon_name ("input-keyboard", Gtk.IconSize.DIALOG);
        image.valign = Gtk.Align.END;

        var title_label = new Gtk.Label (_("Keyboard Layout"));
        title_label.get_style_context ().add_class ("h2");
        title_label.valign = Gtk.Align.START;

        input_language_list_box = new Gtk.ListBox ();
        var input_language_scrolled = new Gtk.ScrolledWindow (null, null);
        input_language_scrolled.add (input_language_list_box);

        var layout_back_button = new Gtk.Button.with_label (_("Input Language"));
        layout_back_button.halign = Gtk.Align.START;
        layout_back_button.margin = 6;
        layout_back_button.get_style_context ().add_class ("back-button");

        var layout_list_title = new Gtk.Label (null);
        layout_list_title.ellipsize = Pango.EllipsizeMode.END;
        layout_list_title.max_width_chars = 20;
        layout_list_title.use_markup = true;

        var layout_list_box = new Gtk.ListBox ();
        var layout_scrolled = new Gtk.ScrolledWindow (null, null);
        layout_scrolled.expand = true;
        layout_scrolled.add (layout_list_box);

        var layout_header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        layout_header_box.add (layout_back_button);
        layout_header_box.set_center_widget (layout_list_title);

        var layout_grid = new Gtk.Grid ();
        layout_grid.orientation = Gtk.Orientation.VERTICAL;
        layout_grid.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        layout_grid.add (layout_header_box);
        layout_grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        layout_grid.add (layout_scrolled);

        var stack = new Gtk.Stack ();
        stack.expand = true;
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        stack.add (input_language_scrolled);
        stack.add (layout_grid);

        var frame = new Gtk.Frame (null);
        frame.add (stack);

        var keyboard_test_entry = new Gtk.Entry ();
        keyboard_test_entry.hexpand = true;
        keyboard_test_entry.placeholder_text = _("Type to test your layout");
        keyboard_test_entry.secondary_icon_activatable = true;
        keyboard_test_entry.secondary_icon_name = "input-keyboard-symbolic";
        keyboard_test_entry.secondary_icon_tooltip_text = _("Show keyboard layout");

        var stack_grid = new Gtk.Grid ();
        stack_grid.orientation = Gtk.Orientation.VERTICAL;
        stack_grid.row_spacing = 12;
        stack_grid.add (frame);
        stack_grid.add (keyboard_test_entry);

        content_area.column_homogeneous = true;
        content_area.margin_end = 12;
        content_area.margin_start = 12;
        content_area.attach (image, 0, 0, 1, 1);
        content_area.attach (title_label, 0, 1, 1, 1);
        content_area.attach (stack_grid, 1, 0, 1, 2);

        var back_button = new Gtk.Button.with_label (_("Back"));

        var next_button = new Gtk.Button.with_label (_("Select"));
        next_button.sensitive = false;
        next_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        action_area.add (back_button);
        action_area.add (next_button);

        input_language_list_box.set_sort_func ((row1, row2) => {
            return ((LayoutRow) row1).layout.description.collate (((LayoutRow) row2).layout.description);
        });

        layout_list_box.set_sort_func ((row1, row2) => {
            if (((VariantRow) row1).code == "") {
                return -1;
            }

            if (((VariantRow) row2).code == "") {
                return 1;
            }

            return ((VariantRow) row1).description.collate (((VariantRow) row2).description);
        });

        back_button.clicked.connect (() => ((Gtk.Stack) get_parent ()).visible_child = previous_view);

        next_button.clicked.connect (() => next_step ());

        layout_back_button.clicked.connect (() => {
            next_button.sensitive = false;
            stack.visible_child = input_language_scrolled;
        });

        input_language_list_box.row_activated.connect ((row) => {
            var layout = ((LayoutRow) row).layout;
            var variants = layout.variants;
            if (variants.is_empty) {
                next_button.sensitive = true;
                return;
            }

            layout_list_box.get_children ().foreach ((child) => {
                child.destroy ();
            });

            layout_list_title.label = "<b>%s</b>".printf (layout.description);
            layout_list_box.add (new VariantRow ("", _("Default")));

            foreach (var variant in variants.entries) {
                layout_list_box.add (new VariantRow (variant.key, variant.value));
            }

            stack.visible_child = layout_grid;
        });

        layout_list_box.row_selected.connect ((row) => {
            next_button.sensitive = true;
        });
        
        keyboard_test_entry.icon_release.connect (() => {
            var popover = new Gtk.Popover (keyboard_test_entry);
            var layout = new LayoutWidget ();
            popover.add (layout);
            popover.show_all ();
        });

        load_layouts ();
        show_all ();
    }

    public void set_language (string lang) {
        
    }

    private void load_layouts () {
        unowned Xml.Doc* doc = Xml.Parser.read_file ("/usr/share/X11/xkb/rules/base.xml");
        Xml.Node* root = doc->get_root_element ();
        Xml.Node* layout_list_node = get_xml_node_by_name (root, "layoutList");
        if (layout_list_node == null) {
            delete doc;
            return;
        }

        for (Xml.Node* layout_iter = layout_list_node->children; layout_iter != null; layout_iter = layout_iter->next) {
            if (layout_iter->type == Xml.ElementType.ELEMENT_NODE) {
                if (layout_iter->name == "layout") {
                    Xml.Node* config_node = get_xml_node_by_name (layout_iter, "configItem");
                    Xml.Node* variant_node = get_xml_node_by_name (layout_iter, "variantList");
                    Xml.Node* description_node = get_xml_node_by_name (config_node, "description");
                    Xml.Node* name_node = get_xml_node_by_name (config_node, "name");
                    if (name_node == null || description_node == null) {
                        continue;
                    }

                    var layout = Layout ();
                    layout.name = name_node->children->content;
                    layout.description = dgettext ("xkeyboard-config", description_node->children->content);
                    var variants = new Gee.HashMap<string, string> ();
                    layout.variants = variants;
                    if (variant_node != null) {
                        for (Xml.Node* variant_iter = variant_node->children; variant_iter != null; variant_iter = variant_iter->next) {
                            if (variant_iter->name == "variant") {
                                Xml.Node* variant_config_node = get_xml_node_by_name (variant_iter, "configItem");
                                if (variant_config_node != null) {
                                    Xml.Node* variant_description_node = get_xml_node_by_name (variant_config_node, "description");
                                    Xml.Node* variant_name_node = get_xml_node_by_name (variant_config_node, "name");
                                    if (variant_description_node != null && variant_name_node != null) {
                                        variants[variant_name_node->children->content] = dgettext ("xkeyboard-config", variant_description_node->children->content);
                                    }
                                }
                            }
                        }
                    }

                    input_language_list_box.add (new LayoutRow (layout));
                }
            }
        }

        delete doc;
    }

    private static Xml.Node* get_xml_node_by_name (Xml.Node* root, string name) {
        for (Xml.Node* iter = root->children; iter != null; iter = iter->next) {
            if (iter->type == Xml.ElementType.ELEMENT_NODE) {
                if (iter->name == name) {
                    return iter;
                }
            }
        }

        return null;
    }

    private class LayoutRow : Gtk.ListBoxRow {
        public Layout layout;
        public LayoutRow (Layout layout) {
            this.layout = layout;

            string layout_description = layout.description;
            if (!layout.variants.is_empty) {
                layout_description = _("%s…").printf (layout_description);
            };

            var label = new Gtk.Label (layout_description);
            label.margin = 6;
            label.xalign = 0;
            label.get_style_context ().add_class ("h3");
            add (label);
            show_all ();
        }
    }

    private class VariantRow : Gtk.ListBoxRow {
        public string code;
        public string description;
        public VariantRow (string code, string description) {
            this.code = code;
            this.description = description;
            var label = new Gtk.Label (description);
            label.margin = 6;
            label.xalign = 0;
            label.get_style_context ().add_class ("h3");
            add (label);
            show_all ();
        }
    }

    private struct Layout {
        public string name;
        public string description;
        public Gee.HashMap<string, string> variants;
    }
}