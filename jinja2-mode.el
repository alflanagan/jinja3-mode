;;; jinja2-mode.el --- A major mode for jinja2 -*- lexical-binding: t -*-

;; Copyright (C) 2011-2022 Florian Mounier aka paradoxxxzero

;; Original Author: Florian Mounier aka paradoxxxzero
;; Author: A Lloyd Flanagan <lloyd.flanagan@pm.me>
;; Version: 0.4

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;   This is an Emacs major mode for jinja2 with:
;;        syntax highlighting
;;        sgml/html integration
;;        indentation (working with sgml)
;;        more to come

;; This file comes from https://github.com/alflanagan/jinja2-mode.git

;;; Code:

(require 'sgml-mode)

(defgroup jinja2 nil
  "Major mode for editing jinja2 code."
  :prefix "jinja2-"
  :group 'languages)

(defcustom jinja2-user-keywords nil
  "Custom keyword names."
  :type '(repeat string)
  :group 'jinja2)

(defcustom jinja2-user-functions nil
  "Custom function names."
  :type '(repeat string)
  :group 'jinja2)

;; (defcustom jinja2-debug nil
;;   "Log indentation logic"
;;   :type 'boolean
;;   :group 'jinja2)

(defun jinja2-closing-keywords ()
  "Return the list of Jinja2 block keywords that take an `end' counterpart.

These are the keywords for which `jinja2-close-tag' will insert a matching
`{% end<keyword> %}' tag (e.g., `{% if %}' → `{% endif %}').
Any entries in `jinja2-user-keywords' are prepended to the built-in list."
  (append
   jinja2-user-keywords
   '("if"
     "for"
     "block"
     "filter"
     "with"
     "raw"
     "macro"
     "autoescape"
     "trans"
     "call")))

(defun jinja2-indenting-keywords ()
  "Return all Jinja2 keywords that affect indentation."
  (append (jinja2-closing-keywords) '("else" "elif")))

(defun jinja2-builtin-keywords ()
  "Return the list of Jinja2 built-in keyword names.

These are highlighted with `font-lock-builtin-face' in `jinja2-mode'."
  '("as"
    "autoescape"
    "debug"
    "extends"
    "firstof"
    "in"
    "include"
    "load"
    "now"
    "regroup"
    "ssi"
    "templatetag"
    "url"
    "widthratio"
    "elif"
    "true"
    "false"
    "none"
    "False"
    "True"
    "None"
    "loop"
    "super"
    "caller"
    "varargs"
    "kwargs"
    "break"
    "continue"
    "is"
    "not"
    "or"
    "and"
    "do"
    "pluralize"
    "set"
    "from"
    "import"
    "context"
    "with"
    "without"
    "ignore"
    "missing"
    "scoped"))

(defun jinja2-functions-keywords ()
  "Return the list of Jinja2 built-in filter and function names."
  (append
   jinja2-user-functions
   '("abs"
     "attr"
     "batch"
     "capitalize"
     "center"
     "default"
     "dictsort"
     "escape"
     "filesizeformat"
     "first"
     "float"
     "forceescape"
     "format"
     "groupby"
     "indent"
     "int"
     "items"
     "join"
     "last"
     "length"
     "list"
     "lower"
     "map"
     "max"
     "min"
     "pprint"
     "random"
     "reject"
     "rejectattr"
     "replace"
     "reverse"
     "round"
     "safe"
     "select"
     "selectattr"
     "slice"
     "sort"
     "string"
     "striptags"
     "sum"
     "title"
     "tojson"
     "trim"
     "truncate"
     "unique"
     "upper"
     "urlencode"
     "urlize"
     "wordcount"
     "wordwrap"
     "xmlattr")))

(defun jinja2-find-open-tag ()
  "Search backward recursively for a Jinja2 open tag."
  (if (search-backward-regexp (rx-to-string
                               `(and "{%"
                                     (?  "-")
                                     (* whitespace)
                                     (?  (group "end"))
                                     (group
                                      ,(append '(or) (jinja2-closing-keywords)))
                                     (group (*? anything))
                                     (* whitespace)
                                     (?  "-")
                                     "%}"))
                              nil t)
      (if (match-string 1) ;; End tag, going on
          (let ((matches (jinja2-find-open-tag)))
            (if (string= (car matches) (match-string 2))
                (jinja2-find-open-tag)
              (list (match-string 2) (match-string 3))))
        (list (match-string 2) (match-string 3)))
    nil))

(defun jinja2-close-tag ()
  "Close the previously opened template tag."
  (interactive)
  (let ((open-tag (save-excursion (jinja2-find-open-tag))))
    (if open-tag
        (insert
         (if (string= (car open-tag) "block")
             (format "{%% end%s%s %%}"
                     (car open-tag)(nth 1 open-tag))
           (format "{%% end%s %%}"
                   (car open-tag))))
      (error "Nothing to close")))
  (save-excursion (jinja2-indent-line)))

(defun jinja2-insert-tag ()
  "Insert an empty tag."
  (interactive)
  (insert "{% ")
  (save-excursion
    (insert " %}")
    (jinja2-indent-line)))

(defun jinja2-insert-var ()
  "Insert an empty variable tag."
  (interactive)
  (insert "{{ ")
  (save-excursion
    (insert " }}")
    (jinja2-indent-line)))

(defun jinja2-insert-comment ()
  "Insert an empty comment tag."
  (interactive)
  (insert "{# ")
  (save-excursion
    (insert " #}")
    (jinja2-indent-line)))

(defconst jinja2-font-lock-comments
  `((,(rx "{#" (* whitespace) (group (*? anything)) (* whitespace) "#}")
     .
     (1 font-lock-comment-face t)))
  "An rx to match a comment and set the the font-lock (syntax highlight).")

(defconst jinja2-font-lock-keywords-1
  (append jinja2-font-lock-comments sgml-font-lock-keywords-1))

(defconst jinja2-font-lock-keywords-2
  (append jinja2-font-lock-keywords-1 sgml-font-lock-keywords-2))

(defconst jinja2-font-lock-keywords-3
  (append
   jinja2-font-lock-keywords-1 jinja2-font-lock-keywords-2
   `((,(rx
        "{{"
        (* whitespace)
        (group (*? anything))
        (* "|" (* whitespace) (*? anything))
        (* whitespace)
        "}}")
      (1 font-lock-variable-name-face t))
     (,(rx (group "|" (* whitespace)) (group (+ word)))
      (1 font-lock-keyword-face t)
      (2 font-lock-warning-face t))
     (,(rx-to-string
        `(and (group "|" (* whitespace))
              (group ,(append '(or) (jinja2-functions-keywords)))))
      (1 font-lock-keyword-face t) (2 font-lock-function-name-face t))
     (,(rx-to-string
        `(and word-start
              (?  "end")
              ,(append '(or) (jinja2-indenting-keywords))
              word-end))
      (0 font-lock-keyword-face))
     (,(rx-to-string
        `(and word-start ,(append '(or) (jinja2-builtin-keywords)) word-end))
      (0 font-lock-builtin-face))

     (,(rx (or "{%" "%}" "{%-" "-%}")) (0 font-lock-function-name-face t))
     (,(rx (or "{{" "}}")) (0 font-lock-type-face t))
     (,(rx "{#" (* whitespace) (group (*? anything)) (* whitespace) "#}")
      (1 font-lock-comment-face t))
     (,(rx (or "{#" "#}")) (0 font-lock-comment-delimiter-face t)))))

(defvar jinja2-font-lock-keywords jinja2-font-lock-keywords-1)

(defvar jinja2-enable-indent-on-save nil)

(defun sgml-indent-line-num ()
  "Indent the current line as SGML."
  (let* ((savep (point))
         (indent-col
          (save-excursion
            (back-to-indentation)
            (if (>= (point) savep)
                (setq savep nil))
            (sgml-calculate-indent))))
    (if (null indent-col)
        0
      (if savep
          (save-excursion indent-col)
        indent-col))))

(defun jinja2-calculate-indent-backward ()
  "Return indent column based on previous lines."
  (let ((indent-width sgml-basic-offset)
        (default (sgml-indent-line-num)))
    (forward-line -1)
    (if (looking-at "^[ \t]*{%-? *end") ; Don't indent after end
        (current-indentation)
      (if (looking-at
           (concat
            "^[ \t]*{%-? *.*?{%-? *end"
            (regexp-opt (jinja2-indenting-keywords))))
          (current-indentation)
        (if (looking-at
             (concat
              "^[ \t]*{%-? *"
              (regexp-opt (jinja2-indenting-keywords)))) ; Check start tag
            (+ (current-indentation) indent-width)
          (if (looking-at "^[ \t]*<") ; Assume sgml block trust sgml
              default
            (if (bobp)
                0
              (jinja2-calculate-indent-backward default))))))))


(defun jinja2-calculate-indent ()
  "Return indent column."
  (if (bobp) ; Check beginning of buffer
      0
    (let ((indent-width sgml-basic-offset)
          (default (sgml-indent-line-num)))
      (if (looking-at "^[ \t]*{%-? *e\\(nd\\|lse\\|lif\\)") ; Check close tag
          (save-excursion
            (forward-line -1)
            (if (and (looking-at
                      (concat
                       "^[ \t]*{%-? *"
                       (regexp-opt (jinja2-indenting-keywords))))
                     (not
                      (looking-at
                       (concat
                        "^[ \t]*{%-? *.*?{% *end"
                        (regexp-opt (jinja2-indenting-keywords))))))
                (current-indentation)
              (- (current-indentation) indent-width)))
        (if (looking-at "^[ \t]*</") ; Assume sgml end block trust sgml
            default
          (save-excursion (jinja2-calculate-indent-backward)))))))

(defun jinja2-indent-line ()
  "Indent current line as Jinja code."
  (interactive)
  (let ((old_indent (current-indentation))
        (old_point (point)))
    (move-beginning-of-line nil)
    (let ((indent (max 0 (jinja2-calculate-indent))))
      (indent-line-to indent)
      (if (< old_indent (- old_point (line-beginning-position)))
          (goto-char (+ (- indent old_indent) old_point)))
      indent)))

(defun jinja2-indent-buffer ()
  "Re-indent every line in the current buffer using `jinja2-indent-line'."
  (interactive)
  (save-excursion (indent-region (point-min) (point-max))))

;;;###autoload
(define-derived-mode
 jinja2-mode
 html-mode
 "Jinja2"
 "Major mode for editing jinja2 files."
 :group
 'jinja2
 (modify-syntax-entry ?\' "\"" sgml-mode-syntax-table)
 (setq-local comment-start "{#")
 (setq-local comment-start-skip "{#")
 (setq-local comment-end "#}")
 (setq-local comment-end-skip "#}")
 (setq-local indent-line-function #'jinja2-indent-line)
 (setq-local font-lock-defaults
             '((jinja2-font-lock-keywords
                jinja2-font-lock-keywords-1
                jinja2-font-lock-keywords-2
                jinja2-font-lock-keywords-3)
               nil t nil nil))

 (when jinja2-enable-indent-on-save
   (add-hook 'after-save-hook #'jinja2-indent-buffer nil t))

 (define-key jinja2-mode-map (kbd "C-c c") 'jinja2-close-tag)
 (define-key jinja2-mode-map (kbd "C-c t") 'jinja2-insert-tag)
 (define-key jinja2-mode-map (kbd "C-c v") 'jinja2-insert-var)
 (define-key jinja2-mode-map (kbd "C-c #") 'jinja2-insert-comment))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.jinja2\\'" . jinja2-mode))
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.j2\\'" . jinja2-mode))

(provide 'jinja2-mode)

;;; jinja2-mode.el ends here
