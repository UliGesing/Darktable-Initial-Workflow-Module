��    n      �  �   �      P	  @   Q	  ]   �	  1   �	  5   "
  �   X
  p   �
  g   b  |   �     G  2   T  �   �  �   +    �  �   �     �  (   �  b   �    5  W   A  s   �       �   ,  �   �  �   q  �   )  F   �  }   "  �   �  k   )  &   �  7   �  �  �  &  �  v   �     6     O  D   j    �  (   �     �  *   �  (   )  *   R  /   }     �     �     �            7   -     e     m     u     �     �     �     �     �               #     <     L     b     |  P   �     �       )     (   H  '   q  (   �     �     �     �  /   
      :   &   L   )   s   ,   �   -   �   &   �   !   !  )   A!     k!     y!     �!     �!     �!     �!     �!     �!     "     ""     A"     U"     t"     �"     �"     �"     �"  3   �"  Q   
#     \#  	   j#     t#     �#     �#  +   �#  k  �#  W   ?%  r   �%  5   
&  9   @&  �   z&  �   F'  U   �'  �   7(     �(  E   �(  �   7)  �   *  K  �*  �   =,     &-  /   2-  �   b-  P  �-  �   C/  �   �/  "   R0  �   u0  �   1    �1  �   �2  ]   �3  �   4  �   �4  �   T5  7   �5  =   6  �  S6  �  A8  �   �9     �:  !   �:  W   �:  =  6;  ,   t<     �<  0   �<  0   �<  /   #=  8   S=     �=     �=     �=     �=     �=  3   	>     =>     F>  '   S>     {>  
   �>  '   �>     �>  $   �>  
   ?  $   ?  *   6?     a?     p?     �?     �?  o   �?     0@     L@  4   j@  2   �@  5   �@  1   A  "   :A     ]A     uA  4   �A     �A  %   �A  7   �A  7   1B  )   iB  (   �B  $   �B  .   �B     C  "    C     CC     bC  6   }C     �C     �C  "   �C  "   �C  0   D     AD  (   SD     |D     �D  +   �D  !   �D      �D  4   E  o   HE     �E     �E     �E     �E      F  3   F     A   ;   F   %   b              !             e                     9   S       /       8   \       #   c   a       I   X       l   m   j       M      ,   +   =       	   L   D   1   5   .   J         >   f       H              n   <   )   P   W         ?   -       4             Q      
   Y       0      G   N   _      d       *          Z   U       $      R       h   V       2           (       `   E              @   g   3       "       7      [      C      &                 k   ]                  O          '   T          K   ^   B       :      6       i    Activate the module to crop the image. Enabled in darkroom view. Activate the module to rotate the image and adjust the perspective. Enabled in darkroom view. Adjust global chroma in color balance rgb module. Adjust global saturation in color balance rgb module. Adjust luminance and chroma contrast. Apply choosen preset (clarity or denoise & sharpen). Choose different values to adjust the strength of the effect. Adjust the white balance of the image by altering the temperature. By default unchanged for the legacy workflow. Apply automatic mask contrast and exposure compensation. Auto adjust the contrast and average exposure. Automatically adjust the exposure correction. Remove the camera exposure bias, useful if you exposed the image to the right. Bayer sensor Choose a predefined preset for your color-grading. Configure all following common settings: Reset all steps to default configurations. These settings are applied during script run, if corresponding step is enabled. Configure all module settings: Keep all modules unchanged or enable all default configurations. These configurations are set, if you choose 'reset' or 'enable' as basic setting. Configure all module settings: a) Select default value. b) Ignore this step / module and do nothing at all. c) Enable corresponding module and set selected module configuration. d) Reset the module and set selected module configuration. e) Disable module and keep it unchanged. Correct chromatic aberrations. Distinguish between Bayer sensor and other camera sensors. This operation uses the corresponding correction module and disables the other. Custom Code Enable and reset lens correction module. Enable denoise (profiled) module. There is nothing to configure, just enable or reset this module. Execute code from TestCustomCode.lua: This file contains some custom debug code. It can be changed without restarting darktable. Just edit, save and execute it. You can use it to try some lua commands on the fly, e.g. dt.gui.action commands. Enabled in darkroom view. Execute module tests. Used during development and deployment. Enabled in darkroom view. Generate the shortest history stack that reproduces the current image. This removes your current history snapshots. OK - script run without errors Perform all configured steps in darkroom for an initial workflow. Perform the steps from bottom to top along the pixel pipeline. Perform color space corrections in color calibration module. Select the adaptation. The working color space in which the module will perform its chromatic adaptation transform and channel mixing. Perform color space corrections in color calibration module. Select the illuminant. The type of illuminant assumed to have lit the scene. By default unchanged for the legacy workflow. Reconstruct color information for clipped pixels. Select an appropriate reconstruction methods to reconstruct the missing data from unclipped channels and/or neighboring pixels. Reset all modules of the whole pixelpipe and discard complete history. Set auto pickers of the module mask and peak white and gray luminance value to normalize the power setting in the 4 ways tab. Show darkroom modules for enabled workflow steps during execution of this initial workflow. This makes the changes easier to understand. Show exposure module to adjust the exposure until the mid-tones are clear enough. Enabled in darkroom view. Show the subpage with common settings. Show the subpage with the configuration of the modules. Some calculations take a certain amount of time. Depending on the hardware equipment also longer.This script waits and attempts to detect timeouts. If steps take much longer than expected, those steps will be aborted. You can configure the default timeout (ms). Before and after each step of the workflow, the script waits this time. In other places also a multiple (loading an image) or a fraction (querying a status). Use Filmic or Sigmoid to expand or contract the dynamic range of the scene to fit the dynamic range of the display. Auto tune filmic levels of black + white relative exposure. Or use Sigmoid with one of its presets. Use only one of Filmic, Sigmoid or Basecurve, this module disables the others. Use preset to compress shadows and highlights with exposure-independent guided filter (eigf) (soft, medium or strong). adjust & compensate bias adjust exposure correction basic setting: Ignore this module or do corresponding configuration. basic setting: a) Select default value. b) Ignore this step / module and do nothing at all. c) Enable corresponding module and set selected module configuration. d) Reset the module and set selected module configuration. e) Disable module and keep it unchanged. checkbox already selected, nothing to do color calibration adaption = %s compress shadows-highlights (eigf): medium compress shadows-highlights (eigf): soft compress shadows-highlights (eigf): strong create widget in lighttable and darkroom panels current adaptation = %s current color processing = %s current correction method = %s current illuminant = %s current value = %s darktable version with appropriate lua API detected: %s default disable disable module if enabled: %s discard complete history enable enable module if disabled: %s exposure & contrast comp. hide module if visible: %s ignore illuminant can be set illuminant cannot be set image file = %s initial workflow done insert test button widget load image number %s of %s loading image failed, reload is performed (this could indicate a timing problem) mask contrast compensation mask exposure compensation module is already disabled, nothing to do module is already enabled, nothing to do module is already hidden, nothing to do module is already visible, nothing to do module test file not found: %s module test finished module test started module tests must be started from darkroom view no image selected nothing to do, adaptation already = %s nothing to do, button is already inactive nothing to do, color processing already = %s nothing to do, correction method already = %s nothing to do, illuminant already = %s nothing to do, value already = %s nothing to do, value already equals to %s other sensors peak white & grey fulcrum process selected images process workflow steps push button off and on: %s reset run script executed from path %s script outputs are in English script translation files in %s selection = %s - %s show module if not visible: %s show modules show settings step timeout = %s ms switch to darkroom view switch to lighttable view this script needs at least darktable 4.8 API to run timeout after %d ms waiting for event %s - increase timeout setting and try again timeout value unchanged view changed to %s white balance workflow canceled workflow canceled - darktable shutting down Project-Id-Version: InitialWorkflowModule
Report-Msgid-Bugs-To: 
PO-Revision-Date: 2023-06-10 10:27+0200
Last-Translator: TheAuthor <TheAuthor@theauthor.com>
Language-Team: English <>
Language: de_DE
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit
Plural-Forms: nplurals=2; plural=(n != 1);
X-Generator: Lokalize 23.04.1
 Das Modul aktivieren, um das Bild zuzuschneiden. In der Dunkelkammer-Ansicht anwendbar. Das Modul aktivieren, um das Bild zu drehen und die Perspektive anzupassen. In der Dunkelkammer-Ansicht anwendbar. Passt die globale Chroma im Farbbalance-RGB-Modul an. Passt die globale Saettigung im Farbbalance-RGB-Modul an. Passen Sie die Luminanz und den Chroma-Kontrast an. Selektierte Voreinstellung anwenden (Klarheit oder entrauschen & schaerfen). Stellen Sie verschiedene Werte ein, um die Staerke des Effekts anzupassen. Passen Sie den Weissabgleich des Bildes mit der passenden Temperatur an. Als Standardvorgabe wird hier beim Legacy-Workflow keine Einstellung vorgenommen. Automatische Anpassung der durchschnittlichen Belichtung und des Kontrasts der Maske. Passen Sie die Belichtungskorrektur automatisch an. Kompensieren Sie die Belichtungskorrektur der Kamera. Dies ist hilfreich, wenn Sie das Bild nach rechts belichtet haben. Bayer-Sensor Bestimmen Sie die Farbkorrektur mit einer vordefinierten Einstellung. Konfiguration für alle diese allgemeinen Einstellungen: Setze für alle Einstellungen den Standardwert. Diese Einstellungen werden während der Ausführung des Skripts angewendet, falls der zugehörige Schritt aktiviert ist. Konfiguration für alle Module: Erhalte alle Module unveraendert oder setze alle Standardeinstellungen. Diese Einstellungen werden angewendet, falls 'standard' oder 'aktivieren' als Grundeinstellung selektiert wird. Konfiguration für alle Module: a) Setze den Standardwert. b) Ignoriere diesen Schritt / dieses Modul und modifiziere nichts. c) Aktiviere das Modul und wende die selektierte Konfiguration an. d) Setze die Standardwerte dieses Moduls und wende die Konfiguration an. e) Deaktiviere das Modul und modifiziere die Einstellungen nicht. Aktiviere das Modul zur Korrektur der chromatischen Aberration. Es wird zwischen Kameras mit Bayer-Sensor und anderen  Sensoren unterschieden. Diese Konfiguration nutzt das passende Korrekturmodul und deaktiviert das jeweils andere. Custom Code Objektivkorrektur aktivieren und zuruecksetzen. Aktiviere das Entrauschen (Profil) Modul. Es gibt hier nichts zu konfigurieren, das Modul kann aktiviert oder auch zuvor zurueckgesetzt werden. Source-Code aus TestCustomCode.lua starten: Diese Datei beinhaltet benutzerdefinierten Debug-Code. Der Code kann angepasst werden, ohne darktable neu zu starten. Einfach bearbeiten, speichern und ausfuehren. Probieren Sie damit einzelne Lua-Befehle im Handumdrehen aus, z.B. dt.gui.action-Befehle. In der Dunkelkammer-Ansicht aktiviert. Modultests durchfuehren. Dies wird waehrend der Entwicklung und Bereitstellung des Skripts verwendet. In Dunkelkammer-Ansicht anwendbar. Generiert einen minimalen Verlaufsstapel, der das gleiche Bild erzeugt. Dadurch werden die aktuellen Snapshots des Verlaufs entfernt. OK - Skript-Durchlauf ohne Fehler. Alle konfigurierten Schritte des Initial-Workflows in der Dunkelkammer anwenden. Die Schritte werden von unten nach oben entlang der Pixelpipeline verarbeitet. Wenden Sie Farbraumkorrekturen im Farbkalibrierungsmodul an. Bestimmen Sie die Art der Adaption. Der Farbraum, in dem das Modul seine chromatische Anpassung und Kanalmischung vornimmt. Wenden Sie Farbraumkorrekturen im Farbkalibrierungsmodul an. Bestimmen Sie das Leuchtmittel. Der Typ des Leuchtmittels, von dem angenommen wird, dass es die Szene beleuchtet hat. Als Standardvorgabe wird hier beim Legacy-Workflow keine Einstellung vorgenommen. Rekonstruieren Sie Farbinformationen der abgeschnittenen Pixel. Bestimmen Sie eine geeignete Rekonstruktionsmethode, um die fehlenden Daten aus nicht abgeschnittenen Kanaelen und/oder benachbarten Pixeln zu rekonstruieren. Verwerfe alle Einstellungen der Module der gesamten Pixelpipeline und den kompletten Verlauf. Passen Sie auf der Registerkarte Maskierung die Spitzenwerte der Weiss- und Grauluminanz automatisch an, um die Potenzfunktion auf der Registerkarte 4 HSL zu normalisieren. Module in der Dunkelkammer anzeigen, dabei die Konfigurationen im Initial-Workflow anwenden. Dadurch sind die Einstellungen leichter nachzuvollziehen. Das Belichtungsmodul anzeigen, um die Belichtung anzupassen, bis die Mitteltoene klar genug sind. In der Dunkelkammer-Ansicht anwendbar. Zeige die Unterseite mit den allgemeinen Einstellungen. Zeige die Unterseite mit den Konfigurationen für die Module. Manche Berechnungen nehmen eine gewisse Zeit in Anspruch. Je nach Hardware-Ausstattung wird mehr Zeit gebraucht. Dieses Skript wartet und versucht Timeouts zu erkennen. Wenn Schritte viel laenger dauern als erwartet, werden diese Schritte abgebrochen. Konfigurieren sie den Standard-Timeout (ms). Vor und nach jedem Schritt des Workflows wartet das Skript diese Zeitspanne. An anderen Stellen auch ein Vielfaches (Laden eines Bildes) oder ein Bruchteil davon (Abfragen eines aktuellen Wertes). Verwenden Sie Filmic oder Sigmoid, um den Dynamikbereich der Szene zu erweitern oder zu verkleinern, um ihn an den Dynamikbereich der Anzeige (des Monitors) anzupassen. Passen Sie mit Filmic die Werte der relativen Schwarz-Weiss-Belichtung automatisch an. Oder verwenden Sie Sigmoid mit einer seiner Voreinstellungen. Es wird nur eines der Module Filmic, Sigmoid oder Basiskurve zugleich aktiviert. Die jeweils anderen werden deaktiviert. Verwenden Sie eine Voreinstellung, um Schatten und Spitzlichter mit einem belichtungsunabhaengigen gefuehrten Filter (eigf) (gering, mittel oder stark) zu komprimieren. Belichtung & BIAS anpassen Belichtungskorrektur kompensieren Grundeinstellung: Ignoriere dieses Modul oder wende die entsprechende Konfiguration an. Grundeinstellung: a) Setze den Standardwert. b) Ignoriere diesen Schritt / dieses Modul und modifiziere nichts. c) Aktiviere das Modul und wende die selektierte Konfiguration an. d) Setze die Standardwerte dieses Moduls und wende die Konfiguration an. e) Deaktiviere das Modul und modifiziere die Einstellungen nicht. Einstellung bereits vorhanden, nichts zu tun Farbkalibrierung Anpassung = %s komprimiert Schatten-Spitzlichter (EIGF): mittel komprimiert Schatten-Spitzlichter (EIGF): gering komprimiert Schatten-Spitzlichter (EIGF): stark Modul in Leuchttisch- und Dunkelkammer-Ansicht erstellen Aktuelle Anpassung = %s aktuelle Farbbehandlung = %s Aktuelle Anpassung = %s Aktuelles Leuchtmittel = %s Aktueller Wert = %s darktable-Version mit passender Lua-API erkannt: %s standard deaktivieren Modul deaktivieren, falls aktiviert: %s Verlauf ganz verwerfen aktivieren Modul aktivieren, falls deaktiviert: %s Belichtung & Kontrast komp. Modul ausblenden, falls sichtbar: %s ignorieren Leuchtmittel kann eingestellt werden Leuchtmittel kann nicht eingestellt werden Bilddatei = %s initial workflow abgeschlossen. Test-Button erzeugen Lade Bild Nummer %s von %s Laden des Bildes ist fehlgeschlagen. Das Bild wird erneut geladen (dies kann auf ein Timing-Problem hinweisen). Maskenkontrast kompensieren Maskenbelichtung kompensieren Modul ist bereits deaktiviert, es gibt nichts zu tun Modul ist bereits aktiviert, es gibt nichts zu tun Modul ist bereits ausgeblendet, es gibt nichts zu tun Modul ist bereits sichtbar, es gibt nichts zu tun Modultest-Datei nicht gefunden: %s Modultest abgeschlossen Modultest gestartet Modultests bitte in der Dunkelkammer-Ansicht starten kein Bild selektiert Nichts zu tun, Anpassung bereits = %s Es gibt nichts zu tun, die Funktion ist bereits inaktiv Nichts zu tun, aktuelle Farbbehandlung ist bereits = %s Nichts zu tun, Anpassung ist bereits = %s Nichts zu tun, Leuchtmittel bereits = %s Nichts zu tun, Wert ist bereits = %s Es gibt nichts zu tun, der Wert ist bereits %s andere Sensoren max. Weiss- und Kontrast-Graupunkt selektierte Bilder verarbeiten Workflow-Schritte anwenden Funktion (Button, Zauberstab) aus- und einschalten: %s zuruecksetzen starten Skript wurde gestartet von Pfad %s Skriptausgaben erfolgen in Deutsch Skript-Lokalisierungsdateien befinden sich in %s Auswahl = %s - %s Modul anzeigen, falls nicht sichtbar: %s Module anzeigen Zeige die Einstellungen Zeitlimit / Timeout dieses Schritts = %s ms Zur Dunkelkammer-Ansicht wechseln Zur Leuchttisch-Ansicht wechseln Dieses Skript erfordert mindestens darktable 4.8 API Timeout nach %d ms beim Warten auf das Event %s - evtl. sollten Sie die Einstellung des Timeout-Werts anpassen. Zeitlimit / Timeout unveraendert Ansicht gewechselt zu %s Weissabgleich Workflow wurde abgebrochen Workflow wurde abgebrochen - darktable wird beendet 