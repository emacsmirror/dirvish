;;; dirvish-updater.el ---  Update a Dirvish instance -*- lexical-binding: t -*-

;; This file is NOT part of GNU Emacs.

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; This library provides functions for updating a Dirvish layout.

;;; Code:

(declare-function all-the-icons-icon-for-file "all-the-icons")
(declare-function all-the-icons-icon-for-dir "all-the-icons")
(declare-function dired-filter--describe-filters "dired-filter")
(defvar dired-filter-mode)
(defvar dired-filter-show-filters)
(defvar dired-filter-revert)
(defvar fd-dired-input-fd-args)
(require 'dirvish-structs)
(require 'dirvish-helpers)
(require 'dirvish-options)
(eval-when-compile
  (require 'subr-x)
  (require 'find-dired))

(when (require 'dired-filter nil t)
  (setq dired-filter-show-filters nil)
  (setq dired-filter-revert 'always))

(defun dirvish--header-line-path ()
  "Compose header string."
  (when-let ((dv (dirvish-curr)))
    (let* ((index (dv-index-path dv))
           (file-path (or (file-name-directory index) ""))
           (path-prefix-home (string-prefix-p (getenv "HOME") file-path))
           (path-regex (concat (getenv "HOME") "/\\|\\/$"))
           (path-tail (replace-regexp-in-string path-regex "" file-path))
           (file-name (file-name-nondirectory index)))
      (format "  %s %s %s"
              (propertize (if path-prefix-home "~" ":"))
              (propertize path-tail 'face 'dired-mark)
              (propertize file-name 'face 'font-lock-constant-face)))))

(defun dirvish--render-icon (pos &optional hl-face)
  "Render icon in POS with optional HL-FACE."
  (let* ((entry (dired-get-filename 'relative 'noerror))
         (offset `(:v-adjust ,dirvish-icon-v-offset))
         (icon-face (unless (eq dirvish-icon-palette 'all-the-icons) `(:face ,dirvish-icon-palette)))
         (icon-attrs (append icon-face offset))
         (icon (if (file-directory-p entry)
                   (apply #'all-the-icons-icon-for-dir entry icon-attrs)
                 (apply #'all-the-icons-icon-for-file entry icon-attrs)))
         (icon-str (concat icon dirvish-icon-delimiter))
         (ov (make-overlay (1- pos) pos)))
    (when-let (hl-face (fg (face-attribute hl-face :foreground))
                       (bg (face-attribute hl-face :background)))
      (add-face-text-property 0 (length icon-str) `(:background ,bg :foreground ,fg) t icon-str))
    (overlay-put ov 'dirvish-icons t)
    (overlay-put ov 'after-string icon-str)))

(defun dirvish--mode-line-sorter ()
  "Return a string showing current Dired file sort criteria."
  (with-current-buffer (window-buffer (dv-root-window (dirvish-curr)))
    (format " %s %s "
            (propertize "Sort:" 'face 'bold)
            (propertize (car (dv-sort-criteria (dirvish-curr))) 'face 'font-lock-type-face))))

(defun dirvish--mode-line-filter ()
  "Return a string showing active Dired file filter."
  (with-current-buffer (window-buffer (dv-root-window (dirvish-curr)))
    (cond ((bound-and-true-p dired-filter-mode)
           (format " %s %s " (propertize "Filters:" 'face 'bold)
                   (dired-filter--describe-filters)))
          (dired-omit-mode (propertize "[Omit]" 'face 'bold)))))

(defun dirvish--mode-line-fd-args ()
  "Return a string showing current `find/fd' command args."
  (with-current-buffer (window-buffer (dv-root-window (dirvish-curr)))
    (when (string-match "^\\*F\\(?:d\\|ind\\)\\*$" (buffer-name))
      (format " %s [%s] "
              (propertize "FD:" 'face 'bold)
              (propertize (or (bound-and-true-p fd-dired-input-fd-args) find-args)
                          'face 'font-lock-string-face)))))

(defun dirvish--mode-line-index ()
  "Return a string showing index in a Dirvish buffer."
  (with-current-buffer (window-buffer (dv-root-window (dirvish-curr)))
    (let ((cur-pos (- (line-number-at-pos (point)) 1))
          (fin-pos (number-to-string (- (line-number-at-pos (point-max)) 2))))
      (format " %d / %s " cur-pos (propertize fin-pos 'face 'bold)))))

(defun dirvish-body-update (&optional skip-icons skip-padding)
  "Update attributes in dirvish body.

By default update icons, padding, and current line.  If
SKIP-ICONS is non-nil, do not update icons.  If SKIP-PADDING is
non-nil, do not update padding."
  (when (and (> dirvish-body-zoom 0) (not skip-padding))
    (save-excursion
      (let ((o (make-overlay (point-min) (point-max))))
        (setq line-spacing dirvish-body-zoom)
        (overlay-put o 'display `(height ,(1+ dirvish-body-zoom))))))
  (remove-overlays (point-min) (point-max) 'dirvish-body t)
  (when-let* ((pos (dired-move-to-filename nil))
              (beg (line-beginning-position))
              (end (line-beginning-position 2))
              (ol (make-overlay beg end)))
    (when dirvish-show-icons
      (unless skip-icons
        (remove-overlays (point-min) (point-max) 'dirvish-icons t)
        (dirvish-render 'dirvish--render-icon))
      (remove-overlays beg end 'dirvish-icons t)
      (dirvish--render-icon pos 'highlight))
    (overlay-put ol 'dirvish-body t)
    (overlay-put ol 'face 'highlight)))

(defun dirvish-mode-line-update ()
  "Show file details in mode line."
  (when-let ((dv (dirvish-curr)))
    (with-current-buffer (dirvish--get-buffer 'footer) (force-mode-line-update))
    (with-current-buffer (dirvish--get-buffer 'header) (force-mode-line-update))))

(provide 'dirvish-updater)
;;; dirvish-updater.el ends here