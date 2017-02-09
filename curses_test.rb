#!/usr/bin/ruby
# rain for a curses test

require "curses"
include Curses



      @tp = RubyCurses::TabbedPane.new @window do
        height 12
        width  50
        row 5
        col 10
      end

      ## add a tab with label Language

      @tab1 = @tp.add_tab "Language"

      ## get the form associated with the tab, so we can create widgets/fields on it

      f1 = @tab1.form
