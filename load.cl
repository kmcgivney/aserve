;; load in iServe
;;
;; $Id: load.cl,v 1.16 2000/03/20 15:56:36 jkf Exp $
;;

(defvar *loadswitch* :compile-if-needed)
(defparameter *iserve-root* (directory-namestring *load-truename*))

(defparameter *iserve-files* 
    '("htmlgen/htmlgen"
      "macs"
      "main"
      "parse"
      "decode"
      "publish"
      "authorize"
      "log" ))

(defparameter *iserve-other-files*
    ;; other files that make up the iserve dist
    '("readme.txt"
      "source-readme.txt"
      "ChangeLog"
      "license-lgpl.txt"
      "examples/examples.cl"
      "examples/foo.txt"
      "examples/fresh.jpg"
      "examples/prfile9.jpg"
      "examples/tutorial.cl"
      "examples/iservelogo.gif"
      "load.cl"
      "doc/iserve.html"
      "doc/tutorial.html"
      "htmlgen/htmlgen.html"
      ))

(defparameter *iserve-examples*
    '("examples/examples"
      ))


(with-compilation-unit  nil
  (dolist (file (append *iserve-files* *iserve-examples*))
    (case *loadswitch*
      (:compile-if-needed (compile-file-if-needed 
			   (merge-pathnames (format nil "~a.cl" file)
					    *load-truename*)))
      (:compile (compile-file 
		 (merge-pathnames (format nil "~a.cl" file)
				  *load-truename*)))
      (:load nil))
    (load (merge-pathnames 
	   (format nil "~a.fasl" file)
	   *load-truename*))))



(defun makeapp ()
  (run-shell-command "rm -fr iserveserver")
  (generate-application
   "iserveserver"
   "iserveserver/"
   '(:sock :process :defftype :foreign :ffcompat "loadonly.cl" "load.cl")
   ; strange use of find-symbol below so this form can be read without
   ; the net.iserve package existing
   :restart-init-function (find-symbol (symbol-name :start-cmd) :net.iserve)
   :application-administration '(:resource-command-line
				 ;; Quiet startup:
				 "-Q")
   :read-init-files nil
   :print-startup-message nil
   :purify nil
   :include-compiler nil
   :include-devel-env nil
   :include-debugger t
   :include-tpl t
   :include-ide nil
   :discard-arglists t
   :discard-local-name-info t
   :discard-source-file-info t
   :discard-xref-info t
 
   :ignore-command-line-arguments t
   :suppress-allegro-cl-banner t))


(defun make-distribution ()
  ;; make a distributable version of iserve
  (run-shell-command 
   (format nil "rm -fr ~aiserve-dist" *iserve-root*))
   
  (run-shell-command 
   (format nil "mkdir ~aiserve-dist ~aiserve-dist/doc ~aiserve-dist/examples"
	   *iserve-root*
	   *iserve-root*
	   *iserve-root*))
   
  (copy-files-to *iserve-files* "iserve.fasl" :root *iserve-root*)
  (copy-files-to '("htmlgen/htmlgen.html")
		 "iserve-dist/doc/htmlgen.html"
		 :root *iserve-root*
		 )
  (dolist (file '("iserve.fasl"
		  "doc/iserve.html"
		  "doc/tutorial.html"
		  "readme.txt"
		  "examples/examples.cl"
		  "examples/examples.fasl"
		  "examples/foo.txt"
		  "examples/fresh.jpg"
		  "examples/prfile9.jpg"))
    (copy-files-to (list file)
		   (format nil "iserve-dist/~a" file)
		   :root *iserve-root*)))
		

(defparameter iserve-version-name 
    (apply #'format nil "iserve-~d.~d.~d" 
	   (symbol-value
	    (find-symbol 
	     (symbol-name :*iserve-version*)
	     :net.iserve))))


(defun make-iserve.fasl ()
  (copy-files-to *iserve-files* "iserve.fasl" :root *iserve-root*))



(defun make-src-distribution ()
  ;; make a source distribution of iserve
  ;;
    
  (run-shell-command "rm -fr iserve-src")
    
  (run-shell-command 
   (format nil "mkdir iserve-src iserve-src/~a iserve-src/~a/htmlgen"
	   iserve-version-name
	   iserve-version-name
	   ))
  
  (run-shell-command 
   (format nil "mkdir iserve-src/~a/doc iserve-src/~a/examples"
	   iserve-version-name
	   iserve-version-name))
	   
  (dolist (file (append (mapcar #'(lambda (file) (format nil "~a.cl" file))
				*iserve-files*)
			*iserve-other-files*))
    (copy-files-to
     (list file)
     (format nil "iserve-src/~a/~a" iserve-version-name file))))


(defun ftp-publish-src ()
  ;; assuming tha we've made the source distribution, tar it
  ;; and copy it to the ftp directory
  (run-shell-command
   (format nil "(cd iserve-src ; tar cfz ~a.tgz ~a)"
	   iserve-version-name
	   iserve-version-name))
  (run-shell-command 
   (format nil "cp iserve-src/~a.tgz /net/candyman/home/ftp/pub/iserve"
	   iserve-version-name)))

  
  

(defun copy-files-to (files dest &key (root ""))
  ;; copy the contents of all files to the file named dest.
  ;; append .fasl to the filenames (if no type is present)
  
  (let ((buffer (make-array 4096 :element-type '(unsigned-byte 8))))
    (with-open-file (p (concatenate 'string root dest)
		     :direction :output
		     :if-exists :supersede
		     :element-type '(unsigned-byte 8))
      (dolist (file files)
	(setq file (concatenate 'string root file))
	(if* (and (null (pathname-type file))
		  (not (probe-file file)))
	   then (setq file (concatenate 'string file  ".fasl")))
	(with-open-file (in file :element-type '(unsigned-byte 8))
	  (loop
	    (let ((count (read-sequence buffer in)))
	      (if* (<= count 0) then (return))
	      (write-sequence buffer p :end count))))))))
