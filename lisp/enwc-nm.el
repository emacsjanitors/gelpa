;;; enwc-nm.el - The NetworkManager backend to ENWC

;; Copyright (C) 2012,2013,2014 Free Software Foundation, Inc.

;; Author: Ian Dunn
;; Keywords: enwc, network, wicd, manager, nm

;; This file is part of ENWC

;; ENWC is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; ENWC is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.

;; You should have received a copy of the GNU General Public License
;; along with ENWC; see the file COPYING.  If not, write to the Free
;; Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
;; 02110-1301, USA.


;;; Commentary:
;;
;;   This requires NetworkManager >= 0.9.6
;;

(require 'enwc)

(defgroup enwc-nm nil
  "*NetworkManager variables for ENWC"
  :prefix "enwc-nm-"
  :group 'enwc)

(defcustom enwc-nm-dbus-service "org.freedesktop.NetworkManager"
  "NetworkManager D-Bus service."
  :group 'enwc-nm
  :type 'string)

(defcustom enwc-nm-dbus-path "/org/freedesktop/NetworkManager"
  "The default D-Bus path for NetworkManager."
  :group 'enwc-nm
  :type 'string)

(defcustom enwc-nm-dbus-settings-path "/org/freedesktop/NetworkManager/Settings"
  "The settings D-Bus path for NetworkManager."
  :group 'enwc-nm
  :type 'string)

(defcustom enwc-nm-dbus-interface "org.freedesktop.NetworkManager"
  "The default D-Bus interface for NetworkManager."
  :group 'enwc-nm
  :type 'string)

(defcustom enwc-nm-dbus-wireless-interface "org.freedesktop.NetworkManager.Device.Wireless"
  "The wireless D-Bus interface for NetworkManager."
  :group 'enwc-nm
  :type 'string)

(defcustom enwc-nm-dbus-wired-interface "org.freedesktop.NetworkManager.Device.Wired"
  "The wired D-Bus interface for NetworkManager."
  :group 'enwc-nm
  :type 'string)

(defcustom enwc-nm-dbus-device-interface "org.freedesktop.NetworkManager.Device"
  "The device D-Bus interface for NetworkManager."
  :group 'enwc-nm
  :type 'string)

(defcustom enwc-nm-dbus-accesspoint-interface "org.freedesktop.NetworkManager.AccessPoint"
  "The access point D-Bus interface for NetworkManager."
  :group 'enwc-nm
  :type 'string)

(defcustom enwc-nm-dbus-settings-interface "org.freedesktop.NetworkManager.Settings"
  "The settings D-Bus interface for NetworkManager."
  :group 'enwc-nm
  :type 'string)

(defcustom enwc-nm-dbus-connections-interface "org.freedesktop.NetworkManager.Settings.Connection"
  "The connections D-Bus interface for NetworkManager."
  :group 'enwc-nm
  :type 'string)

(defcustom enwc-nm-dbus-active-interface "org.freedesktop.NetworkManager.Connection.Active"
  "The active connection D-Bus interface for NetworkManager."
  :group 'enwc-nm
  :type 'string)

(defvar enwc-nm-details-list
  '("Ssid" "HwAddress" "Strength" "Flags" "Mode" "Frequency")
  "The list of the desired details to be obtained from each network.")

(defvar enwc-nm-sec-types
  '(("eap-leap" . (("Name" . "eap-leap")
                   ("reqs" . ((("identity" . "Username")
                               ("password" . "Password"))))))
    ("eap-peap" . (("Name" . "eap-peap")
                   ("reqs" . ((("anonymous-identity" . "Anonymous Identity")
                               ("ca-cert" . "CA Certificate")
                               ("phase2-auth" . "Inner Authentication")
                               ("phase1-peapver" . "PEAP Version")
                               ("identity" . "Username")
                               ("password" . "Password"))))))
    ("eap-tls" . (("Name" . "eap-tls")
                  ("reqs" . ((("identity" . "Identity")
                              ("client-cert" . "User Certificate")
                              ("ca-cert" . "CA Certificate")
                              ("private-key" . "Private Key")
                              ("private-key-password" . "Private Key Password"))))))
    ("eap-ttls" . (("Name" . "eap-ttls")
                   ("reqs" . ((("anonymous-identity" . "Anonymous Identity")
                               ("ca-cert" . "CA Certificate")
                               ("phase2-auth" . "Inner Authentication")
                               ("identity" . "Username")
                               ("password" . "Password"))))))
    ("wpa-psk" . (("Name" . "wpa2")
                  ("reqs" . ((("psk" . "PSK"))))))
    ("wep" . (("Name" . "wep")
              ("reqs" . ((("wep-key0" . "WEP Key")
                          ("wep-key-type" . "WEP Key Type"))))))
    ("leap" . (("Name" . "leap")
               ("reqs" . ((("leap-username" . "Username")
                           ("leap-password" . "Password"))))))
    )
  "The security types for NetworkManager.
This is still in the process of being worked on."
  )

(defvar enwc-nm-wired-dev nil
  "The wired device object path.")

(defvar enwc-nm-wireless-dev nil
  "The wireless device object path.")

(defvar enwc-nm-active-ap nil
  "The active access point object path.")

(defvar enwc-nm-connecting-p nil
  "Whether or not NetworkManager is connecting.")

(defvar enwc-nm-wired-p nil
  "Whether or not NetworkManager is wired.")

(defvar enwc-nm-edit-info nil
  "The information for the network connection being edited.")

(defun enwc-nm-dbus-call-method (method &optional path interface &rest args)
  (unless path (setq path enwc-nm-dbus-path))
  (unless interface (setq interface enwc-nm-dbus-interface))
  (apply 'dbus-call-method :system
         enwc-nm-dbus-service
         path
         interface
         method
         :timeout 25000
         args))

(defun enwc-nm-dbus-default-call-method (method &rest args)
  (enwc-nm-dbus-call-method method nil nil args))

(defun enwc-nm-dbus-settings-call-method (method &rest args)
  (enwc-nm-dbus-call-method method
                            enwc-nm-dbus-settings-path
                            enwc-nm-dbus-settings-interface
                            args))

(defun enwc-nm-dbus-wireless-call-method (method &rest args)
  (enwc-nm-dbus-call-method method
                            enwc-nm-wireless-dev
                            enwc-nm-dbus-wireless-interface
                            args))

(defun enwc-nm-dbus-wired-call-method (method &rest args)
  (enwc-nm-dbus-call-method method
                            enwc-nm-wired-dev
                            enwc-nm-dbus-wired-interface
                            args))

(defun enwc-nm-get-settings (conn)
  "Gets the connection settings.
CONN is an object path to the connection."
  (dbus-call-method :system
                    enwc-nm-dbus-service
                    conn
                    enwc-nm-dbus-connections-interface
                    "GetSettings"
                    :timeout 25000))

(defun enwc-nm-list-connections ()
  "List the connections."
  (enwc-nm-dbus-settings-call-method "ListConnections"))

;; Default
(defun enwc-nm-get-device-by-name (name)
  (enwc-nm-dbus-default-call-method "GetDeviceByIpIface" :string name))

;; Settings, Connections
(defun enwc-nm-get-uuid-by-ssid (ssid)
  "Gets the uuid of the network with ssid SSID."
  (let ((conns (enwc-nm-list-connections))
        cur-conn cur-ssid uuid)
    (while (and conns (not uuid))
      (setq cur-conn (pop conns))
      (let ((settings (enwc-nm-get-settings cur-conn)))
        (when (assoc "802-11-wireless" settings)
          (setq cur-ssid
                (dbus-byte-array-to-string (car (cadr (assoc "ssid"
                                                             (cadr (assoc "802-11-wireless"
                                                                          settings)))))))
          (when (string= cur-ssid ssid)
            (setq uuid
                  (car (cadr (assoc "uuid"
                                    (cadr (assoc "connection"
                                                 settings))))))))))
    uuid))

(defun enwc-nm-get-uuid-by-id (id)
  "Gets a network connection's uuid by the network's id.
ID is a string that NetworkManager uses to identify this network."
  (let ((conns (enwc-nm-list-connections))
        cur-conn cur-id uuid)
    (while (and conns (not uuid))
      (setq cur-conn (pop conns))
      (let ((settings (enwc-nm-get-settings cur-conn))
            conn-set)
        (if (not (assoc "connection" settings))
            nil
          (setq conn-set (assoc "connection" settings))
          (setq cur-id (car (cadr (assoc "id" (cadr conn-set)))))
          (if (string= cur-id id)
              (setq uuid (car (cadr (assoc "uuid" (cadr conn-set)))))))))))

(defun enwc-nm-get-conn-by-uuid (uuid)
  (enwc-nm-dbus-settings-call-method "GetConnectionByUuid"
                                     uuid))

;; Settings
;; Not used.
(defun enwc-nm-get-conn-by-ssid (ssid)
  "Gets the connection path for the access point with ssid SSID."
  (let ((uuid (enwc-nm-get-uuid-by-ssid ssid)))
    (if uuid
        (enwc-nm-get-conn-by-uuid uuid)
      nil)))

;; Not used.
(defun enwc-nm-get-conn-by-id (id)
  "Gets a connection object with the id ID.
ID is the identifier used by Network Manager."
  (let ((uuid (enwc-nm-get-uuid-by-id id)))
    (enwc-nm-get-conn-by-uuid uuid)))

;;;;;;;;;;;;;;;;;
;; Get networks
;;;;;;;;;;;;;;;;;

(defun enwc-nm-get-networks (&optional wired)
  (if wired
      (enwc-nm-get-wired-profiles)
    (enwc-nm-get-wireless-networks)))

(defun enwc-nm-get-wireless-networks ()
  "The NetworkManager get networks function.
This returns a list of D-Bus paths to the access points."
  (enwc-nm-dbus-wireless-call-method "GetAccessPoints"))

(defun enwc-nm-get-wired-profiles ()
  (let ((profs-list (enwc-nm-list-connections)))
    (mapcar
     (lambda (x)
       (let ((props (enwc-nm-get-settings x)))
         (when (string= (caar props) "connection")
           (car (cadr (car (cadr (car props))))))))
     profs-list)))

;;;;;;;;;;;;;
;; Connect ;;
;;;;;;;;;;;;;

;; Default
(defun enwc-nm-connect (nw &optional wired)
  "The NetworkManager connect function.
This gets the connection path from NW, and connects to it."
  (if wired
      (enwc-nm-wired-connect nw)
    (enwc-nm-wireless-connect nw)))

(defun enwc-nm-wireless-connect (nw)
  (enwc-nm-dbus-default-call-method "ActivateConnection"
                                    :object-path nw
                                    :object-path enwc-nm-wireless-dev
                                    :object-path nw))

(defun enwc-nm-wired-connect (nw)
  (enwc-nm-dbus-default-call-method "ActivateConnection"
                                    :object-path nw
                                    :object-path enwc-nm-wired-dev
                                    :object-path nw))

;;;;;;;;;;;;;;;;
;; Disconnect ;;
;;;;;;;;;;;;;;;;

(defun enwc-nm-disconnect (&optional wired)
  (if wired
      (enwc-nm-wired-disconnect)
    (enwc-nm-disconnect-wireless)))

;; Device
(defun enwc-nm-disconnect-wireless ()
  (enwc-nm-dbus-call-method "Disconnect"
                            enwc-nm-wireless-dev
                            enwc-nm-dbus-device-interface))

(defun enwc-nm-wired-disconnect ()
  (enwc-nm-dbus-call-method "Disconnect"
                            enwc-nm-wired-dev
                            enwc-nm-dbus-device-interface))

;;;;;;;;;;
;; Scan ;;
;;;;;;;;;;

(defun enwc-nm-scan (&optional wired)
  "The NetworkManager scan function."
  (let ((dev (if wired
                 enwc-nm-wired-dev
               enwc-nm-wireless-dev))
        (interface (if wired
                       enwc-nm-dbus-wired-interface
                     enwc-nm-dbus-wireless-interface)))
    (enwc-nm-dbus-call-method "RequestScan"
                              dev interface
                              '(:array :signature "{sv}"))
    ;; (dbus-call-method :system
    ;;                   enwc-nm-dbus-service
    ;;                   dev
    ;;                   interface
    ;;                   "RequestScan"
    ;;                   :timeout 25000
    ;;                   '(:array :signature "{sv}"))
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Get network properties
;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun enwc-nm-get-wireless-network-property (nw prop)
  "The NetworkManager get wireless network property function.
This runs like normal, using element ID of `enwc-access-points'
 to determine the access point path, then obtains the property
PROP from that access point.  It also sets the channel from the
 frequency if necessary."
  (dbus-get-property :system
                     enwc-nm-dbus-service
                     nw
                     enwc-nm-dbus-accesspoint-interface
                     prop))

(defun enwc-nm-prop-to-prop (prop)
  "Converts a NetworkManager property to an ENWC network property."
  (pcase prop
    ("Ssid" 'essid)
    ("HwAddres" 'bssid)
    ("Strength" 'strength)
    ("Flags" 'encrypt)
    ("Mode" 'mode)
    ("Channel" 'channel)))

(defun enwc-nm--freq-to-channel (freq)
  "Convert a frequency FREQ into a channel."
  (1+ (/ (- freq 2412) 5)))

(defun enwc-nm-get-wireless-nw-props (nw)
  "Gets the network properties for the network NW."
  (let ((props (dbus-get-all-properties :system
                                        enwc-nm-dbus-service
                                        nw
                                        enwc-nm-dbus-accesspoint-interface)))

    `((essid    . ,(dbus-byte-array-to-string (cdr (assoc "Ssid" props))))
      (bssid    . ,(cdr (assoc "HwAddres" props)))
      (strength . ,(cdr (assoc "Strength" props)))
      (encrypt  . ,(or (enwc-nm-get-encryption-type nw) "Unsecured"))
      (channel  . ,(number-to-string (enwc-nm--freq-to-channel
                                      (cdr (assoc "Frequency" props))))))))

(defun enwc-nm-get-conn-by-nid (nid)
  "Gets a connection object with the network id NID."
  (let* ((ssid (enwc-nm-get-wireless-network-property nid
                                                      "Ssid"))
         (uuid (enwc-nm-get-uuid-by-ssid ssid)))
    (when uuid
      (enwc-nm-get-conn-by-uuid uuid))))

(defun enwc-nm-get-encryption-type (nw)
  "The NetworkManager get encryption type function.
This gets the WPA flags and RSN flags from access point in NW.
If both are 0, then it returns WEP, otherwise WPA."
  (let ((wpa-flags (enwc-nm-get-wireless-network-property nw "WpaFlags"))
        (rsn-flags (enwc-nm-get-wireless-network-property nw "RsnFlags")))
    (if (and (= wpa-flags 0) (= rsn-flags 0))
        "WEP"
      "WPA")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Get Current network id
;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun enwc-nm-string-idx (obj ls)
  "Determine the index of string OBJ in LIST."
  (unless (stringp obj)
    (signal 'wrong-type-argument `(stringp ,obj)))
  (unless (listp ls)
    (signal 'wrong-type-argument `(listp ,ls)))
  (let ((tmp-list ls)
        (cur-pos -1)
        cur-obj)
    (while (and (not cur-obj) tmp-list)
      (setq cur-obj (pop tmp-list))
      (setq cur-pos (1+ cur-pos))
      (unless (string= obj cur-obj)
        (setq cur-obj nil)))
    cur-pos))

(defun enwc-nm-wireless-prop-changed (props)
  "Called when network properties are changed.
PROPS is a list of updated properties."
  (let ((ap (assoc "ActiveAccessPoint" props)))
    (when ap
      (setq enwc-nm-active-ap (car (cadr ap))))))

(defun enwc-nm-get-current-nw-id (wired)
  "The NetworkManager get current network id function.
This simply checks for the active access point."
  (cond
   (wired 'wired)
   ((string= enwc-nm-active-ap "/") nil)
   (t enwc-nm-active-ap)))

(defun enwc-nm-prop-changed (state)
  "Called when NetworkManager's state is changed.
STATE is the new state."
  (setq enwc-nm-connecting-p (eq state 40)))

;;;;;;;;;;;;;;;;;;;;;
;; Check Connecting
;;;;;;;;;;;;;;;;;;;;;

(defun enwc-nm-check-connecting ()
  "The NetworkManager check connecting function."
  enwc-nm-connecting-p)

;; Settings, Connections

;; Device

(defun enwc-nm-dev-prop-changed (new-state old-state reason)
  (setq enwc-nm-wired-p (eq new-state 100)))

;; Default
(defun enwc-nm-is-wired ()
  enwc-nm-wired-p)

;; Each entry in sec-types should be:
;; ("IDENT" (("Name" . "NAME") ("reqs" . (("key1" . "Entry1") ("key2" . "Entry2") ... ))))
;; Where:
;;  "IDENT" => String that identifies this to the backend.
;;  "NAME" => String that ENWC displays
;;  "reqs" => Constant string, but the association list holds entries
;;              required by the security type, i.e. user, passphrase, etc.
;;  "keyXX" => String that the backend uses for this security entry.
;;  "EntryXX" => String that ENWC displays for this security entry.

(defun enwc-nm-get-sec-types (&optional wired)
  "Get security types."
  (if wired
      nil
    enwc-nm-sec-types))

(defun enwc-nm-gen-uuid ()
  (random t)
  (let ((hex-nums
         (mapcar (lambda (x)
                   (random 65535))
                 (number-sequence 0 7)))
        fin-str)
    (setq fin-str (apply 'format "%04x%04x-%04x-%04x-%04x-%04x%04x%04x" hex-nums))))

(defmacro enwc-nm--hex-substring (str st ed)
  "Get a standard integer from hex string STR starting at ST and ending st ED"
  `(string-to-number (substring ,str ,st ,ed) 16))

(defun enwc-nm-convert-addr (addr)
  (if addr
      (let* ((hex-addr (format "%08x" addr))
             (subs (mapcar
                    (lambda (n)
                      (enwc-nm--hex-substring hex-addr n (+ n 2)))
                    (number-sequence 6 0 -2))))
        (apply 'format "%i.%i.%i.%i" subs))
    ""))

(defun enwc-nm-addr-back (addr)
  (let* ((bytes (split-string addr "\\."))
         (byte-string (mapcar
                       (lambda (n) (lsh (string-to-number (nth (- 3 n) bytes)) n))
                       (number-sequence 0 3))))
    (apply 'logior byte-string)))

;; These next two come from libnm-util/nm-utils.c in NM's source.

(defun enwc-nm-netmask-to-prefix (netmask)
  "Converts a netmask to a prefix.
NETMASK is an ip address in network byte order."
  (if netmask
      (let* ((mask netmask)
             (cur-pos 3)
             (cur-mark (logand (lsh mask (* -8 cur-pos)) 255))
             (pf 0))
        (while (and (eq cur-mark 255) (>= cur-pos 0))
          (setq pf (+ pf 8))
          (setq cur-pos (1- cur-pos))
          (setq cur-mark (logand (lsh mask (* -8 cur-pos)) 255)))

        (if (>= cur-pos 0)
            (let ((v (logand (lsh mask (* -8 cur-pos)) 255)))
              (while (not (eq v 0))
                (setq pf (1+ pf))
                (setq v (lsh v 1)))))
        pf)
    0))

(defun enwc-nm-prefix-to-netmask (prefix)
  "Converts a prefix to a netmask.
PREFIX is an integer <= 32."
  (if (not (integerp prefix))
      (signal 'wrong-type-argument `(integerp ,prefix)))
  (let ((pf prefix)
        (netmask 0)
        (msk #x80000000))
    (while (> pf 0)
      (setq netmask (logior netmask msk))
      (setq msk (lsh msk -1))
      (setq pf (1- pf)))
    netmask))

(defun enwc-nm-get-profile-info (id &optional wired)
  (let ((conn (enwc-nm-get-conn-by-nid id)))
    (when conn
      (setq enwc-nm-edit-info
            (enwc-nm-get-settings conn))))

  (let (ip-addr netmask gateway dns-list nw-info)
    (when enwc-nm-edit-info
      (setq ip-addr (nth 0 (caar (cadr (assoc "addresses" (cadr (assoc "ipv4" enwc-nm-edit-info))))))
            netmask (nth 3 (caar (cadr (assoc "addresses" (cadr (assoc "ipv4" enwc-nm-edit-info))))))
            gateway (nth 2 (caar (cadr (assoc "address"   (cadr (assoc "ipv4" enwc-nm-edit-info))))))
            dns-list (car (cadr (assoc "dns" (cadr (assoc "ipv4" enwc-nm-edit-info))))))
      (setq ip-addr (enwc-nm-convert-addr ip-addr)
            netmask (enwc-nm-convert-addr netmask)
            gateway (enwc-nm-convert-addr gateway)
            dns-list (mapcar 'enwc-nm-convert-addr
                             dns-list))
      `(("addr" . ,ip-addr)
        ("netmask" . ,netmask)
        ("gateway" . ,gateway)
        ("dns1"    . ,(nth 0 dns-list))
        ("dns2"    . ,(nth 1 dns-list)))
      nil)))

(defun enwc-nm-get-ip-addr (wired id)
  "Gets the IP Address of a connection profile."
  (let ((props (enwc-nm-get-settings (enwc-nm-get-conn-by-nid id)))
        ipaddr ret-addr)
    (if (not props)
        (setq ret-addr "")
      (setq ipaddr (nth 0 (caar (cadr (assoc "addresses"
                                             (cadr (assoc "ipv4"
                                                          props)))))))
      (setq ret-addr (enwc-nm-convert-addr ipaddr)))))

(defun enwc-nm-get-netmask (wired id)
  "Gets the Netmask of a connection profile."
  (let ((props (enwc-nm-get-settings (enwc-nm-get-conn-by-nid id)))
        ipaddr hex-addr ret-addr)
    (if (not props)
        (setq ret-addr "")
      (setq ipaddr (nth 3 (caar (cadr (assoc "addresses"
                                             (cadr (assoc "ipv4"
                                                          props)))))))
      (setq hex-addr (enwc-nm-prefix-to-netmask ipaddr))
      (setq ret-addr (format "%i.%i.%i.%i"
                             (logand hex-addr 255)
                             (logand (lsh hex-addr -8) 255)
                             (logand (lsh hex-addr -16) 255)
                             (logand (lsh hex-addr -24) 255))))))

(defun enwc-nm-get-gateway (wired id)
  "Gets the Gateway of a connection profile."
  (let ((props (enwc-nm-get-settings (enwc-nm-get-conn-by-nid id)))
        ipaddr ret-addr)
    (if (not props)
        (setq ret-addr "")
      (setq ipaddr (nth 2 (caar (cadr (assoc "addresses"
                                             (cadr (assoc "ipv4"
                                                          props)))))))
      (setq ret-addr (enwc-nm-convert-addr ipaddr)))))

(defun enwc-nm-get-dns (wired id)
  "Gets the DNS settings of a connection profile."
  (let ((props (enwc-nm-get-settings (enwc-nm-get-conn-by-nid id)))
        dns-list)
    (setq dns-list (car (cadr (assoc "dns" (cadr (assoc "ipv4"
                                                        props))))))
    (mapcar 'enwc-nm-convert-addr
            dns-list)))

(defun enwc-nm-process-enctype (settings nw-settings)
  "Process the encryption type.
Sets up the encryption type passed in through SETTINGS."
  (let* ((ret-list nw-settings)
         (req-list (nthcdr 6 settings))
         (enctype (cdr (assoc "enctype" settings)))
         key-mgmt
         new-list name-list
         key-name)

    ;; There is a possibility that any of these don't exist in
    ;; nw-settings.

    (setq new-list `("802-11-wireless-security" (("pairwise" (("wep40" "wep104")))
                                                 ("group" (("wep40" "wep104")))
                                                 ("auth-alg" (nil))
                                                 ("key-mgmt" (nil)))))

    (if (not (assoc "802-11-wireless-security" ret-list))
        (setq ret-list (append ret-list (list new-list))))

    (if (or (string= enctype "eap-leap")
            (string= enctype "eap-peap")
            (string= enctype "eap-tls")
            (string= enctype "eap-ttls"))
        (progn
          (setq key-name "802-1x")
          (setq key-mgmt "ieee8021x")
          (setq req-list (push (cons "eap" (substring enctype 4)) req-list)))
      (setq key-name "802-11-wireless-security")
      (setq key-mgmt
            (cond ((string= enctype "wep") "none")
                  ((string= enctype "wpa-psk") "wpa-psk")
                  ((string= enctype "leap") "iee8021x"))))
    (setcdr (assoc "key-mgmt" (cadr (assoc "802-11-wireless-security" ret-list)))
            (list (list key-mgmt)))

    (when (string= enctype "leap")
      (setcdr (assoc "auth-alg" (cadr (assoc "802-11-wireless-security" ret-list)))
              (list (list "leap"))))

    (setq name-list (cons key-name
                          (list (mapcar (lambda (x)
                                          (cons (car x)
                                                (cons (cons (cdr x) nil)
                                                      nil)))
                                        req-list))))

    (if (not (assoc key-name ret-list))
        (setq ret-list (append ret-list (list name-list)))
      (setcdr (assoc key-name ret-list) (list name-list)))


    (when (or (string= enctype "eap-leap")
              (string= enctype "eap-peap")
              (string= enctype "eap-tls")
              (string= enctype "eap-ttls"))
      (setcdr (assoc "eap" (cadr (assoc "802-1x" ret-list)))
              (cons (cons (cons (substring enctype 4) nil) nil) nil)))

    ret-list))

(defun enwc-nm-finalize-settings (settings)
  "Sets up all of the D-BUS types of a settings list.
SETTINGS is the list of settings list to setup.
This will place all of the necessary markers in the list,
such as :array, :dict-entry, etc."
  (cons :array
        (let (first-one)
          (dolist (x settings)
            (setq first-one (cons :dict-entry first-one))
            (setq first-one
                  (cons
                   (cons :string
                         (cons (car x)
                               (cons
                                (cons :array
                                      (let (this-one)
                                        (dolist (y (cadr x))
                                          (setq this-one
                                                (cons :dict-entry this-one))
                                          (setq this-one
                                                (cons
                                                 (list
                                                  :string (car y)
                                                  :variant
                                                  (if (string= (car y) "ssid")
                                                      (cons (dbus-string-to-byte-array
                                                             (dbus-byte-array-to-string (car (cadr y))))
                                                            nil)
                                                    (cadr y)))
                                                 this-one)))
                                        (nreverse this-one)))
                                nil)))
                   first-one)))
          (nreverse first-one))))

(defun enwc-nm-create-settings (wired ssid)
  (let ((uuid (enwc-nm-gen-uuid))
        (id (concat ssid " settings"))
        type
        ret-list
        conn-list
        ipv4-list ipv6-list
        mod-list
        new-ssid
        80211-list)

    (if (not wired)
        (setq new-ssid (dbus-string-to-byte-array ssid))
      (progn
        (setq 80211-list `("802-11-wireless" (("security" (nil))
                                              ("ssid" (,new-ssid))
                                              ("mode" ("infrastructure")))))

        (setq ret-list (append ret-list (list 80211-list))
              type "802-11-wireless"))
      (setq type "802-3-ethernet"))
    (setq conn-list `("connection" (("id" (,id))
                                    ("uuid" (,uuid))
                                    ("autoconnect" (nil))
                                    ("type" (,type)))))

    (setq ipv4-list '("ipv4" (("addresses" (nil))
                              ("dns" (nil))
                              ("method" ("auto"))
                              ("routes" (nil)))))

    (setq ipv6-list '("ipv4" (("addresses" (nil))
                              ("dns" (nil))
                              ("method" ("auto"))
                              ("routes" (nil)))))

    (setq ret-list (append ret-list (list conn-list)))
    (setq ret-list (append ret-list (list ipv4-list)))
    (setq ret-list (append ret-list (list ipv6-list)))))

(defun enwc-nm-setup-settings (wired id settings)
  "Sets up NetworkManager settings.
Gets the current network properties of network ID
and uses the information in the association list SETTINGS
to put it in the form that NetworkManager will recognize."
  (let (ssid uuid conn props)

    (if (not enwc-nm-edit-info)
        (progn
          (setq ssid
                (enwc-nm-get-wireless-network-property (nth id
                                                            enwc-access-points)
                                                       "Ssid"))
          (setq props (enwc-nm-create-settings wired ssid)))
      (setq props enwc-nm-edit-info))

    (setcdr (assoc "type" (cadr (assoc "connection" props)))
            (list (list (cond (wired "802-3-ethernet")
                              ((not wired) "802-11-wireless")))))

    (if (= (length (cdr (assoc "addr" settings))) 0)
        (setcdr (assoc "addresses" (cadr (assoc "ipv4" props)))
                (cons (cons nil nil) nil))

      (setcdr (assoc "addresses" (cadr (assoc "ipv4" props)))
              (list (list (list (list (enwc-nm-addr-back
                                       (cdr (assoc "addr" settings)))
                                      (enwc-nm-netmask-to-prefix (enwc-nm-addr-back
                                                                  (cdr (assoc "netmask"
                                                                              settings))))
                                      (enwc-nm-addr-back
                                       (cdr (assoc "gateway" settings)))))))))

    (if (= (length (cdr (assoc "dns1" settings))) 0)
        (setcdr (assoc "dns" (cadr (assoc "ipv4" props)))
                (cons (cons nil nil) nil))
      (setcdr (assoc "dns" (cadr (assoc "ipv4" props)))
              (list (list (list (enwc-nm-addr-back
                                 (cdr (assoc "dns1" settings)))
                                (enwc-nm-addr-back
                                 (cdr (assoc "dns2" settings))))))))

    (setq props (enwc-nm-process-enctype settings props))

    (enwc-nm-finalize-settings props)))

(defun enwc-nm-save-nw-settings (wired id settings)
  "Saves network settings.
ID is the network id of the profile to save,
WIRED denotes whether or not this is a wired profile,
and SETTINGS is the list of settings."
  (let ((mod-sets (enwc-nm-setup-settings wired id settings)))
    (dbus-call-method :system
                      enwc-nm-dbus-service
                      (enwc-nm-get-conn-by-nid id)
                      enwc-nm-dbus-connections-interface
                      (if (not enwc-nm-edit-info)
                          "AddConnection"
                        "Update")
                      :timeout 25000
                      :array mod-sets)))

(defun enwc-nm-setup ()
  (setq enwc-nm-wired-dev (enwc-nm-get-device-by-name enwc-wired-device)
        enwc-nm-wireless-dev (enwc-nm-get-device-by-name enwc-wireless-device))

  (dbus-register-signal :system
                        enwc-nm-dbus-service
                        enwc-nm-wireless-dev
                        enwc-nm-dbus-wireless-interface
                        "AccessPointAdded"
                        'enwc-process-scan)

  (dbus-register-signal :system
                        enwc-nm-dbus-service
                        enwc-nm-wireless-dev
                        enwc-nm-dbus-wireless-interface
                        "AccessPointRemoved"
                        'enwc-process-scan)

  (setq enwc-nm-active-ap
        (let ((cur-net (dbus-get-property :system
                                          enwc-nm-dbus-service
                                          enwc-nm-wireless-dev
                                          enwc-nm-dbus-wireless-interface
                                          "ActiveAccessPoint")))
          (if (string= cur-net "/")
              "/"
            cur-net)))

  (dbus-register-signal :system
                        enwc-nm-dbus-service
                        enwc-nm-wireless-dev
                        enwc-nm-dbus-wireless-interface
                        "PropertiesChanged"
                        'enwc-nm-wireless-prop-changed)

  (setq enwc-nm-connecting-p
        (let ((state (dbus-get-property :system
                                        enwc-nm-dbus-service
                                        enwc-nm-dbus-path
                                        enwc-nm-dbus-interface
                                        "State")))
          (eq state 40)))

  (dbus-register-signal :system
                        enwc-nm-dbus-service
                        enwc-nm-wired-dev
                        enwc-nm-dbus-device-interface
                        "StateChanged"
                        'enwc-nm-dev-prop-changed)

  (setq enwc-nm-wired-p
        (let ((state (dbus-get-property :system
                                        enwc-nm-dbus-service
                                        enwc-nm-wired-dev
                                        enwc-nm-dbus-device-interface
                                        "State")))
          (eq state 100)))
  (dbus-register-signal :system
                        enwc-nm-dbus-service
                        enwc-nm-dbus-path
                        enwc-nm-dbus-interface
                        "StateChanged"
                        'enwc-nm-prop-changed))


(provide 'enwc-nm)

;;; End of File.
