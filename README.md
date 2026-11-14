# Tendie Studio — V1

Ein iPhone-Editor-Prototyp für PosterBoard-Wallpaper-Projekte.

## V1-Funktionen
- SwiftUI-Lockscreen-Vorschau
- Bilder/GIF-Dateien über die Dateien-App importieren
- Ebenen auswählen, verschieben, skalieren, drehen und Deckkraft ändern
- CoreMotion-Gyroskop-Livevorschau mit Tiefen-/X-/Y-Empfindlichkeit
- 12-Sekunden-Keyframe-Timeline (Keyframes werden im Projekt gespeichert)
- Projektentwurf als JSON-Datei mit der Endung .tendies

## Wichtige Einschränkungen
Der Export ist in V1 ein **Tendie-Studio-Projektentwurf**, noch kein bestätigtes Placard-/PosterBoard-kompatibles Descriptor- oder Container-.tendies-Paket. Das genaue Format muss anhand echter Beispieldateien und der PosterBoard-Spezifikation implementiert und getestet werden. Die Gyro-Funktion ist eine Livevorschau innerhalb der App; iOS stellt keine allgemeine API bereit, mit der eine beliebige Drittanbieter-Wallpaperdatei dauerhaft auf Gyroskopbewegungen reagieren kann.

Die GIF-Datei wird als Quelldatei in das Projekt übernommen; die aktuelle Vorschau hängt von der iOS-Bilddekodierung ab. Video-Rendering, echte Keyframe-Wiedergabe und CAML-/PosterBoard-Export sind noch nicht Bestandteil dieser ersten Testfassung.

## Build
GitHub Actions baut auf einem gehosteten macOS-Runner eine unsignierte IPA und veröffentlicht sie als Workflow-Artefakt. Für die Installation auf einem iPhone muss die IPA mit AltStore/LiveContainer bzw. einem passenden Signierweg installiert werden.
