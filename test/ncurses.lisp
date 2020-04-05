(in-package :de.anvi.ncurses.test)

;; here the ncurses primitive bindings should be tested.

(defun nctest ()
  (initscr)
  (mvaddstr 0 0 "hello there")
  (mvaddstr 7 7 "hello there")
  (mvaddstr 15 15 "hello there")
  (refresh)
  (getch)
  (endwin))

(defun nctest2 ()
  (let ((scr (initscr)))
    (mvaddstr 0 0 "hello there")
    
    (wattron scr #x00020000)
    (mvaddstr 7 7 "hello there")
    (wattroff scr #x00020000)

    (wattron scr #x80000000)
    (mvaddstr 15 15 "hello there")
    (wattroff scr #x80000000)

    (wrefresh scr)
    (wgetch scr)
    (endwin)))

(defun nctest3 ()
  (initscr)
  (start-color)
  (init-pair 1 1 3) ; red(1) on yellow(3)

  ;; extract and display the foreground and background color numbers from the pair number
  (cffi:with-foreign-objects ((ptr-f :short)
                              (ptr-b :short))
    (pair-content 1 ptr-f ptr-b)
    (mvaddstr 0 0 (format nil "1 ~A, 3 ~A" (cffi:mem-aref ptr-f :short) (cffi:mem-aref ptr-b :short))))

  ;; extract and display the RGB contents of predefined color no. 3 (yellow).
  (cffi:with-foreign-objects ((ptr-r :short)
                              (ptr-g :short)
                              (ptr-b :short))
    (color-content 3 ptr-r ptr-g ptr-b)
    (mvaddstr 1 0 (format nil "~3A ~3A ~3A"
                           (cffi:mem-aref ptr-r :short)
                           (cffi:mem-aref ptr-g :short)
                           (cffi:mem-aref ptr-b :short))))
  
  (color-set 1 (cffi:null-pointer))
  (mvaddstr 5 0 "hello")

  ;; problem: even though color 3 (yellow) is a predefined color, it is NOT predefined with the
  ;; predefined ncurses rgb value, 680, but with some other rgb, probably the terminal default palette
  ;; since the colors xterm shows are different than what gnome-terminal shows.

  ;; also, initializing the color redefines the color everywhere, not just for subsequent uses of that color.

  ;; so we can _NOT_ print the rgb values of the 256 colors, because they are terminal specific and cant
  ;; be queried, we just get nonsensical values from ncurses.

  ;; but we can find the rgb values for the xterm colors on the web, and then define these in ncurses.

  ;; before we do init-color, we should do can-change-color
  ;; can-change-color checks whether we can change what color is displayed by a color number.
  ;; some terminals have a hard coded palette.

  ;; BOLD simply makes the color bringhter. if red is 680, then red bold is 1000.
  ;; so what happens when we apply bold to 1000? nothing?
  
  (init-color 3 680 680 0)
  (mvaddstr 6 0 "hello")
  
  ;; TODO: display the hex code of the color
  ;; TODO: display the name of the color from its number

  (refresh)
  (getch)
  (endwin))

(defun nctest4 ()
  "Test low-level cchar_t reading and writing.

The output is:

a          rendered cchar_t
97         code of character #\a
1          color pair 1
00020100   attribute underline #x00020000 OR-ed with bit-shifted color pair 1

We see that the attr_t slot contains _both_ the attribute _and_ the
bit-shifted color pair, as if it were a chtype in ABI5.

When ABI6 is used, the separate color-pair slot contains the same color
pair number.

The goal is obviously to make the cchar_t usable under both ABI5 and ABI6."
  (let ((scr (initscr)))
    (start-color)
    (init-pair 1 1 3) ; red(1) on yellow(3)

    (cffi:with-foreign-objects ((ptr '(:struct cchar_t))
                                (wch 'wchar_t 5))
      (dotimes (i 5) (setf (cffi:mem-aref wch 'wchar_t i) 0))
      (setf (cffi:mem-aref wch 'wchar_t) (char-code #\a))
      ;;(setcchar ptr wch attr_t color-pair-number (null-pointer))
      (setcchar ptr wch #x00020000 1 (cffi:null-pointer))
      (wadd-wch scr ptr))

    ;; access the struct slots directly using slot pointers
    (cffi:with-foreign-object (ptr '(:struct cchar_t))
      (mvwin-wch scr 0 0 ptr)
      (let* ((char (cffi:mem-aref (cffi:foreign-slot-pointer ptr '(:struct cchar_t) 'cchar-chars) 'wchar_t 0))
             (col (cffi:foreign-slot-value ptr '(:struct cchar_t) 'cchar-colors))
             (attr (cffi:foreign-slot-value ptr '(:struct cchar_t) 'cchar-attr)))
        ;; char code
        (mvaddstr 1 0 (format nil "~A" char))
        ;; color pair number
        (mvaddstr 2 0 (format nil "~A" col))
        ;; attr_t in hex.
        (mvaddstr 3 0 (format nil "~8,'0x" attr))))

    ;; deconstruct cchar_t using getcchar
    (cffi:with-foreign-objects ((wcval '(:struct cchar_t))
                                (wch 'wchar_t 5)
                                (attrs 'attr_t)
                                (color-pair :short))
      (dotimes (i 5) (setf (cffi:mem-aref wch 'wchar_t i) 0))
      (mvwin-wch scr 0 0 wcval)
      (getcchar wcval wch attrs color-pair (cffi:null-pointer))
      
      (mvaddstr 5 0 (format nil "~A" (cffi:mem-aref wch 'wchar_t 0)))
      (mvaddstr 6 0 (format nil "~A" (cffi:mem-aref color-pair :short)))
      (mvaddstr 7 0 (format nil "~8,'0x" (cffi:mem-aref attrs 'attr_t))))

    (refresh)
    (getch)
    (endwin)))

;; 190302
(defun nctest5 ()
  (let ((scr (initscr)))
    (addstr (format nil "~A~%" "no background "))
    (wgetch scr)

    (wbkgd scr (char-code #\-))
    (addstr (format nil "~A~%" "background minus "))
    (wgetch scr)

    (wbkgd scr (char-code #\*))
    (addstr (format nil "~A~%" "background star "))
    (wgetch scr)

    (wbkgd scr (char-code #\-))
    (addstr (format nil "~A~%" "background minus "))
    (wgetch scr)

    (wbkgd scr (char-code #\+))
    (addstr (format nil "~A~%" "background plus "))
    (wgetch scr)
    
    (wrefresh scr)
    (wgetch scr)
    (endwin)))

;; 190826
(defun nctest6 ()
  (let ((scr (initscr)))
    (start-color)
    (init-pair 1 1 3) ; red(1) on yellow(3)
    (init-pair 2 2 7) ; green(2) on white(7)
    
    (color-set 1 (cffi:null-pointer))
    (addstr (format nil "color-set: red on yellow~%"))
    (getch)

    ;; a background color overwrites the window color.
    (bkgdset (logior (char-code #\.) (color-pair 2)))
    (addstr (format nil "bkgd: green on white~%"))
    (getch)
    
    (addch (char-code #\a))
    (addch (char-code #\b))
    (addch (char-code #\space)) ;; trying to write space will actually write the background char #\.
    (addch (char-code #\space))
    (addch (char-code #\c))
    (getch)

    ;; the next call to color-set again overwrites the color set by bkgd
    (color-set 1 (cffi:null-pointer))
    (addstr (format nil "color-set: red on yellow~%"))
    (getch)

    ;; (erase) and (clear) use the last bkgd char to overwrite the window.
    (clear)
    (getch)
    
    (bkgdset (color-pair 2))
    (addstr (format nil "bkgdset: green on white~%"))
    (getch)

    (bkgd (color-pair 0))
    (addstr (format nil "bkgd: default colors~%"))
    (getch)

    (clear)
    (getch)

    ;; color-set and bgkd write to the same global window variable.
    ;; so using both at the same time doesnt make sense.
    
    (bkgdset (logior (char-code #\.) (color-pair 2)))
    (color-set 1 (cffi:null-pointer))
    (addstr (format nil "bkgd green on white, then color-set: red on yellow~%"))
    (refresh)

    (getch)
    
    (endwin)))

(defun nctest7 ()
  (let ((scr (initscr)))
    (start-color)

    ;; init-pair 0 7 0 ; white(7) on black (0) - default color pair
    (init-pair 1 1 3) ; red(1) on yellow(3)
    (init-pair 2 7 0) ; white(7) on black(0)
    
    (addch (char-code #\a))
    
    (color-set 1 (cffi:null-pointer))

    (addch (char-code #\b))

    ;; when we set a color pair to a window, ncurses wont let use use the default color pair any more
    ;; the default color pair is ignored and overwritten by the window color pair
    (addch (logior (char-code #\c) (color-pair 0)))

    ;; we can actually use the default color pair, but have to give it another color pair number
    (addch (logior (char-code #\d) (color-pair 2)))

    (color-set 0 (cffi:null-pointer))

    (addch (char-code #\e))
    
    (refresh)

    (getch)
    
    (endwin)))

;; 190901
(defun nctest8 ()
  (let ((scr (initscr)))
    (start-color)

    ;;(use-default-colors)
    ;; is the same as
    ;;(assume-default-colors -1 -1)
    
    ;; we can not combine any other color with -1
    ;; as soon as one color (fg or g) is -1, the other automatically is set to -1.
    ;; this is the case for unrendered characters added without color attributes.
    (assume-default-colors 5 -1)

    ;; init-pair 0 7 0 ; white(7) on black (0) - default color pair
    (init-pair 1 1 3) ; red(1) on yellow(3)
    (init-pair 2 7 0) ; white(7) on black(0)

    ;; -1 are not the terminal colors, but the (assumed) default colors.
    (init-pair 3 -1 -1)
    
    ;; as soon as one of the assumed default colors is -1,
    ;; the other is also set to -1 for unrendered characters.
    (addch (char-code #\a))

    ;; when we reference 5 -1 in a color pair, then the mixed pair works.
    (addch (logior (char-code #\d) (color-pair 3)))
    
    (addch (logior (char-code #\b) (color-pair 1)))
    (addch (logior (char-code #\c) (color-pair 2)))
        
    (refresh)

    (getch)
    
    (endwin)))
