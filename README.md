# EasyVNC

Ce projet a pour but d'automatiser une connexion de type "bureau à distance" vers un pc distant au travers d'un tunnel SSH.

L'avantage par rapport à une connexion VNC classique est double : le premier est que la communication est entièrement sécurisée/chiffrée par le protocole SSH, le second est qu'il n'y a aucune configuration réseau (port spécifique à rediriger au niveau de la box et dans le pare-feu de l'ordinateur) à effectuer que ce soit côté serveur ou bien côté client.

Au niveau réseau, le serveur VNC établit au démarrage de la machine un tunnel SSH permanent vers un serveur "relais". Le client se connecte au serveur "relais" à la demande et récupère la liste des machines accessibles.

Au niveau technique il y a un script d'installation ("Setup.cmd") pour mettre en place le serveur VNC (= la machine que l'on souhaite contrôler) qui comprend également un script de mise à jour automatique ("Module_MAJ.bat"), il y a également un script ("VNC_Viewer.bat") pour le client VNC (= la machine qui prend le contrôle).
