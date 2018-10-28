(in-package :de.anvi.croatoan)

;; menu
;; curses extension for programming menus
;; http://invisible-island.net/ncurses/man/menu.3x.html

(defun list2array (list dimensions)
  "Example: (list2array '(a b c d e f) '(3 2)) => #2A((A B) (C D) (E F))"
  (let ((m (car dimensions))
        (n (cadr dimensions)))
    (assert (= (length list) (* m n)))
    (let ((array (make-array dimensions :initial-element nil)))
      (loop for i from 0 to (- m 1)
         do (loop for j from 0 to (- n 1)
               do (setf (aref array i j) (nth (+ (* i n) j) list))))
      array)))

;; TODO: see menu_format
(defun rmi2sub (layout rmi)
  "Take array dimensions and an index in row-major order, return two subscripts.

Example: (rmi2sub '(2 3) 5) => (1 2)"
  (let ((m (car layout))
        (n (cadr layout)))
    (assert (< rmi (* m n)))
    (multiple-value-bind (q r) (floor rmi n)
      (list q r))))

(defun sub2rmi (layout subs)
  "Take array dimensions and two subscripts, return an index in row-major order.

Example: (sub2rmi '(2 3) '(1 2)) => 5"
  (let ((m (car layout))
        (n (cadr layout))
        (i (car subs))
        (j (cadr subs)))
    (assert (and (< i m) (< j n)))
    (+ (* i n) j)))

(defun update-menu (menu event)
  "Take a menu and an event, update in-place the current item of the menu."
  ;; we need to make menu special in order to setf i in the passed menu object.
  (declare (special menu))
  (with-accessors ((item .current-item-number) (items .items) (layout .layout) (cyclic-selection .cyclic-selection)
                   (scrolled-layout .scrolled-layout) (scrolled-region-start .scrolled-region-start)) menu
    (let ((i  (car  (rmi2sub layout item)))
          (j  (cadr (rmi2sub layout item)))
          (m  (car  layout))
          (n  (cadr layout))
          (m0 (car  scrolled-region-start))
          (n0 (cadr scrolled-region-start))
          (m1 (car  scrolled-layout))
          (n1 (cadr scrolled-layout)))
      (if scrolled-layout
          ;; when scrolling is on, the menu is not cycled.
          (progn
            (case event
              (:up    (when (> i 0) (decf i))             ; when not in first row, move one row up
                      (when (< i m0) (decf m0)))          ; when above region, move region one row up
              (:down  (when (< i (1- m)) (incf i))        ; when not in last row, move one row down
                      (when (>= i (+ m0 m1)) (incf m0)))  ; when below region, move region one row down
              (:left  (when (> j 0) (decf j))             ; when not in first column, move one column left
                      (when (< j n0) (decf n0)))          ; when left of region, move region one column left
              (:right (when (< j (1- n)) (incf j))        ; when not in last column, move one column right
                      (when (>= j (+ n0 n1)) (incf n0)))) ; when right of region, move region one column right

            ;; set new scrolled-region coordinates
            (setf scrolled-region-start (list m0 n0)))

          ;; when scrolling is off, the menu can be cycled.
          (if cyclic-selection
                ;; do cycle through the items
                (case event
                  (:up    (setf i (mod (1- i) m)))
                  (:down  (setf i (mod (1+ i) m)))
                  (:left  (setf j (mod (1- j) n)))
                  (:right (setf j (mod (1+ j) n))))
                ;; dont cycle through the items
                (case event
                  (:up    (setf i (max (1- i) 0)))
                  (:down  (setf i (min (1+ i) (1- m))))
                  (:left  (setf j (max (1- j) 0)))
                  (:right (setf j (min (1+ j) (1- n)))))))

      ;; after updating i,j, update the current-item-number
      (setf item (sub2rmi layout (list i j))))))

(defun format-menu-item (menu item-number)
  (with-accessors ((items .items)
                   (checklist .checklist)
                   (type .type)
                   (current-item-number .current-item-number)
                   (mark .current-item-mark)
                   (sub-window .sub-window)) menu
    (format sub-window "~A~A~A"
            ;; two types of menus: :selection :checklist
            ;; only show the checkbox before the item in checklists
            (if (eq type :checklist)
                (if (nth item-number checklist) "[X] " "[ ] ")
                "")
            ;; for the current item, draw the current-item-mark
            ;; for all other items, draw a space
            (if (= current-item-number item-number)
                mark
                (make-string (length mark) :initial-element #\space))
            ;; then add the item
            (let ((item (nth item-number items)))
              (typecase item
                (symbol (symbol-name item))
                (string item)
                (menu-item (.name item)))))))

(defgeneric draw-menu (s)
  (:documentation "Draw a menu."))

(defmethod draw-menu ((menu menu-window))
  (with-accessors ((current-item-number .current-item-number) (mark .current-item-mark) (items .items) (layout .layout)
                   (scrolled-layout .scrolled-layout) (scrolled-region-start .scrolled-region-start)
                   (title .title) (border .border) (color-pair .color-pair) (len .max-item-length) (sub-win .sub-window)) menu
    (clear sub-win)
    (let ((m  (car  layout))
          (n  (cadr layout))
          (m0 (car  scrolled-region-start))
          (n0 (cadr scrolled-region-start))
          (m1 (car  scrolled-layout))
          (n1 (cadr scrolled-layout)))
      (if scrolled-layout
          ;; when the menu is too big to be displayed at once, only a part
          ;; is displayed, and the menu can be scrolled
          ;; draw a menu with a scrolling layout enabled
          (loop for i from 0 to (1- m1)
             do (loop for j from 0 to (1- n1)
                   do
                   ;; the menu is given as a flat list, so we have to access it as a 2d array in row major order
                   ;; TODO: rename to item-number
                     (let ((item (sub2rmi layout (list (+ m0 i) (+ n0 j)))))
                       ;;(format menu "~A ~A," j n0)
                       (move sub-win i (* j len))
                       (format-menu-item menu item)
                       ;; change the attributes of the current item
                       (when (= current-item-number item)
                         (move sub-win i (* j len))
                         (change-attributes sub-win len '(:reverse) )))))

          ;; when there is no scrolling, and the whole menu is displayed at once
          ;; cycling is enabled.
          (loop for i from 0 to (1- m)
             do (loop for j from 0 to (1- n)
                   do
                     (let ((item (sub2rmi layout (list i j))))
                       (move sub-win i (* j len))
                       (format-menu-item menu item)
                       ;; change the attributes of the current item
                       (when (= current-item-number item)
                         (move sub-win i (* j len))
                         (change-attributes sub-win len '(:reverse) )))))))

    ;; we have to explicitely touch the background win, because otherwise it wont get refreshed.
    (touch menu)
    ;; draw the title only when we have a border too, because we draw the title on top of the border.
    (when (and border title)
      ;; "|~12:@<~A~>|"
      (flet ((make-title-string (len)
               (concatenate 'string "|~" (write-to-string (+ len 2)) ":@<~A~>|")))
        (add menu (format nil (make-title-string (length title)) title) :y 0 :x 2)))
    ;; TODO: when we refresh a window with a subwin, we shouldnt have to refresh the subwin separately.
    ;; make refresh specialize on menu and decorated window in a way to do both.
    (refresh menu)
    (refresh sub-win)))

(defmethod draw-menu ((menu dialog-window))
  ;; first draw a menu
  (call-next-method)

  ;; then draw the message in the reserved space above the menu.
  (with-accessors ((message-text .message-text) (message-height .message-height)
                   (message-pad .message-pad) (coords .message-pad-coordinates)) menu
    ;; if there is text, and there is space reserved for the text, draw the text
    (when (and message-text (> message-height 0))
      (refresh message-pad
               0                   ;pad-min-y
               0                   ;pad-min-x
               (first  coords)     ;screen-min-y
               (second coords)     ;screen-min-x
               (third  coords)     ;screen-max-y
               (fourth coords))))) ;screen-max-x

(defun current-item (menu)
  "Return the currently selected item of the given menu."
  (nth (.current-item-number menu) (.items menu)))

;; test submenus, test this in t19c
(defun select-item (menu)
  "Display a menu, let the user select an item, return the selected item.

If the item is itself a menu, recursively display the sub menu."
  (setf (.visible menu) t)
  ;; TODO: how to better avoid refresh-stack when we have no submenus?
  (when *window-stack* (refresh-stack))
  (draw-menu menu)
  (event-case (menu event)
    ((:up :down :left :right) (update-menu menu event) (draw-menu menu))

    ;; x toggles whether the item is checked or unchecked (if menu type is a checklist)
    ((#\x #\space)
     (when (eq (.type menu) :checklist)
       (let ((i (.current-item-number menu)))
         (setf (nth i (.checklist menu))
               (not (nth i (.checklist menu))))
         (draw-menu menu))))

    ;; ENTER either enters a submenu or returns a selected item.
    (#\newline
     ;; if the menu type is a checklist
     (if (eq (.type menu) :checklist)
         ;; return all checked items in a list.
         (with-accessors ((items .items) (checklist .checklist)) menu
           (return-from select-item (loop for i from 0 below (length items) if (nth i checklist) collect (nth i items))))

         ;; else, if the menu type is selection, act on the current item.
         (let ((item (current-item menu)))
           (typecase item
             ;; if we have just a normal string or a symbol, just return it.
             (symbol
              (setf (.visible menu) nil)
              (when *window-stack* (refresh-stack))
              (return-from event-case item))
             (string
              ;; when an item is selected, hide the menu or submenu, then return the item
              (setf (.visible menu) nil)
              (when *window-stack* (refresh-stack))
              (return-from event-case item))
             ;; a more complex item can be a sub menu, or in future, a function.
             (menu-item
              (when (eq (.type item) :menu)
                ;; if the item is a menu, call select-item recursively on the sub-menu
                (let ((selected-item (select-item (.value item))))
                  ;; if we exit the submenu with q without selecting anything, we go back to the parent menu.
                  ;; we only exit the menu completely if something is selected.
                  ;; for all this to work, we have to put the overlapping menu windows in the stack.
                  (when selected-item
                    ;; when a submenu returns non-nil, hide the parent menu too.
                    ;; when the submenu is exited with q, it returns nil, and we go back to the parent menu.
                    (setf (.visible menu) nil)
                    (when *window-stack* (refresh-stack))
                    (return-from event-case selected-item)))))))))

    ;; quitting a menu by pressing q just returns NIL
    (#\q
     ;; when q is hit to exit a menu, hide the menu or submenu, then refresh the whole stack.
     (setf (.visible menu) nil)
     (when *window-stack* (refresh-stack))
     (return-from event-case nil))))
