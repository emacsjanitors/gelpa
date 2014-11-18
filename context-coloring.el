(require 'json)

;;; Faces

(defface context-coloring-depth-0-face
  '((((background light)) (:foreground "#ffffff"))
    (((background dark)) (:foreground "#ffffff")))
  "Nested blocks face, depth 0 - outermost set."
  :tag "Rainbow Blocks Depth 0 Face -- OUTERMOST"
  :group 'context-coloring-faces)

(defface context-coloring-depth-1-face
  '((((background light)) (:foreground "#ffff80"))
    (((background dark)) (:foreground "#ffff80")))
  "Nested blocks face, depth 1."
  :group 'context-coloring-faces)

(defface context-coloring-depth-2-face
  '((((background light)) (:foreground "#cdfacd"))
    (((background dark)) (:foreground "#cdfacd")))
  "Nested blocks face, depth 2."
  :group 'context-coloring-faces)

(defface context-coloring-depth-3-face
  '((((background light)) (:foreground "#d8d8ff"))
    (((background dark)) (:foreground "#d8d8ff")))
  "Nested blocks face, depth 3."
  :group 'context-coloring-faces)

(defface context-coloring-depth-4-face
  '((((background light)) (:foreground "#e7c7ff"))
    (((background dark)) (:foreground "#e7c7ff")))
  "Nested blocks face, depth 4."
  :group 'context-coloring-faces)

(defface context-coloring-depth-5-face
  '((((background light)) (:foreground "#ffcdcd"))
    (((background dark)) (:foreground "#ffcdcd")))
  "Nested blocks face, depth 5."
  :group 'context-coloring-faces)

(defface context-coloring-depth-6-face
  '((((background light)) (:foreground "#ffe390"))
    (((background dark)) (:foreground "#ffe390")))
  "Nested blocks face, depth 6."
  :group 'context-coloring-faces)

(defface context-coloring-depth-7-face
  '((((background light)) (:foreground "#cdcdcd"))
    (((background dark)) (:foreground "#cdcdcd")))
  "Nested blocks face, depth 7."
  :group 'context-coloring-faces)

(defconst context-coloring-face-count 8
  "Number of faces defined for highlighting delimiter levels.
Determines depth at which to cycle through faces again.")

;;; Face utility functions

(defsubst context-coloring-depth-face (depth)
  "Return face-name for DEPTH as a string 'context-coloring-depth-DEPTH-face'.
For example: 'context-coloring-depth-1-face'."
  (intern-soft
   (concat "context-coloring-depth-"
           (number-to-string
            (or
             ;; Has a face directly mapping to it.
             (and (< depth context-coloring-face-count)
                  depth)
             ;; After the number of available faces are used up, pretend the 0th
             ;; face doesn't exist.
             (+ 1
                (mod (- depth 1)
                     (- context-coloring-face-count 1)))))
           "-face")))

(defsubst context-coloring-get-point (line column)
  (save-excursion
    (goto-line line)
    (move-to-column column)
    (point)))

;;; The coloring.

(defconst context-coloring-path
  (file-name-directory (or load-file-name buffer-file-name)))

(defun context-coloring-propertize-region (start end)
  (interactive)
  (let* ((json (shell-command-to-string
                (format "echo '%s' | %s"
                        (buffer-substring-no-properties
                         (point-min)
                         (point-max))
                        (expand-file-name "./tokenizer/tokenizer" context-coloring-path))))
         (tokens (let ((json-array-type 'list))
                   (json-read-from-string json))))
    (with-silent-modifications
      (dolist (token tokens)
        (let* ((line (cdr (assoc 'line token)))
               (from (cdr (assoc 'from token)))
               (thru (cdr (assoc 'thru token)))
               (level (cdr (assoc 'level token)))
               (start (context-coloring-get-point line (- from 1)))
               (end (context-coloring-get-point line (- thru 1)))
               (face (context-coloring-depth-face level)))
          (add-text-properties start end `(font-lock-face ,face rear-nonsticky t)))))))

;;; Minor mode:

;;;###autoload
(define-minor-mode context-coloring-mode
  "Context-based code coloring for JavaScript, inspired by Douglas Crockford."
  nil " Context" nil
  (if (not context-coloring-mode)
      (progn
        (jit-lock-unregister 'context-coloring-propertize-region))
    (jit-lock-register 'context-coloring-propertize-region)))

;;;###autoload
(defun context-coloring-mode-enable ()
  (context-coloring-mode 1))

;;;###autoload
(defun context-coloring-mode-disable ()
  (context-coloring-mode 0))

;;;###autoload
(define-globalized-minor-mode global-context-coloring-mode
  context-coloring-mode context-coloring-mode-enable)

(provide 'context-coloring)
