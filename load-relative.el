(provide 'load-relative)
(defun __FILE__ (&optional symbol)
  "Return the string name of file/buffer that is currently begin executed.

The first approach for getting this information is perhaps the
most pervasive and reliable. But it the most low-level and not
part of a public API, so it might change in future
implementations. This method uses the name that is recorded by
readevalloop of `lread.c' as the car of variable
`current-load-list'.

Failing that, we use `load-file-name' which should work in some
subset of the same places that the first method works. However
`load-file-name' will be nil for code that is eval'd. To cover
those cases, we try `buffer-file-name' which is initially
correct, for eval'd code, but will change and may be wrong if the
code sets or switches buffers after the initial execution.

As a last resort, you can pass in SYMBOL which should be some
symbol that has been previously defined if none of the above
methods work we will use the file-name value find via
`symbol-file'."
  (cond 
     ;; lread.c's readevalloop sets the (car current-load-list)
     ;; load-list via LOADHIST_ATTACH of lisp.h. At least in Emacs
     ;; 23.0.91 and this code goes back to '93.
     ((stringp (car-safe current-load-list)) (car current-load-list))
     (load-file-name)     ;; load-like things
     ((buffer-file-name)) ;; eval-like things
     (t (symbol-file symbol)) ;; last resort
     ))

(defun load-relative (file-or-list &optional symbol)
  "Load an Emacs Lisp file relative to Emacs Lisp code that is in
the process of being loaded or eval'd.

FILE-OR-LIST is either a string or a list of strings containing
files that you want to loaded.

WARNING: it is best to to run this function before any
buffer-setting or buffer changing operations."

  (if (listp file-or-list)
      (mapcar (lambda(relative-file)
		(load (relative-expand-file-name relative-file symbol)))
		file-or-list)
    (load (relative-expand-file-name file-or-list symbol))))

(defun relative-expand-file-name(relative-file &optional symbol)
  "Expand RELATIVE-FILE relative to the Emacs Lisp code that is in
the process of being loaded or eval'd."
  (let ((prefix (file-name-directory 
		 (or (__FILE__ symbol) default-directory))))
    (expand-file-name (concat prefix relative-file))))

(defun require-relative (relative-file &optional symbol)
  "Run `require' on an Emacs Lisp file relative to the Emacs Lisp code
that is in the process of being loaded or eval'd.

WARNING: it is best to to run this function before any
buffer-setting or buffer changing operations."
  (let ((require-string-name 
	 (file-name-sans-extension 
	  (file-name-nondirectory relative-file))))
    (require (intern require-string-name) 
	       (relative-expand-file-name relative-file symbol))))
