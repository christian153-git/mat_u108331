/**
* Name: meisen_vs_eps
* Based on the internal empty template. 
* Author: Christian Schneider
* Tags:
* 
* Beschreibung:
* GAML-Code zur Masterarbeit von Christian Schneider, u108331, im Rahmen des Universitätslehrgangs 
* „Geographical Information Science & Systems“ (UNIGIS MSc) an der Universität Salzburg.
*
* Lizenz:
* Dieser Code ist urheberrechtlich geschützt. Jegliche Nutzung, Vervielfältigung oder Weitergabe
* bedarf der ausdrücklichen Genehmigung des Autors.
*  
*/


model meisen_vs_eps

global {
	
	// Einladen des Stadtgebiets aus der GeoJSON
	file stadt_gt <- file("../includes/stadtgebiet.geojson");
	geometry shape <- envelope(stadt_gt);
	geometry stadt_gt_geom <- geometry(stadt_gt);

	// Einladen der Bäume aus der GeoJSON
	file befallen <- file("../includes/eps.geojson");
	geometry befallen_geom <- geometry(befallen);
	
	// Einladen der Meisen Nistkasten Standorte aus der GeoJSON
	file kasten <- file("../includes/kaesten.geojson");
	geometry kasten_geom <- geometry(kasten);
	container<geometry> meisenkaesten <- kasten as list<geometry>;
	

	
	// Nur ausführen für simulierte Kästen
	// !!!KEINE REALDATEN!!!
	// Einladen der Meisen Nistkasten Standorte aus der GeoJSON
	//file kasten <- file("../includes/simulierte_kaesten.geojson");
	//geometry kasten_geom <- geometry(kasten);
	//container<geometry> meisenkaesten <- kasten as list<geometry>;  
	
	// Beginn der Simulation
	date start <- date(2024, 4, 15);
	
	// Ende der Simulation
	// 108 Tage nach Simulationsbeginn
	date end <- date(2024, 7, 31);
	
	// Benötigte Variablen zur Zeitsteuerung
	int stunden <- 0;
	int minuten <-0;
	int aktueller_zeitschritt <- 0;
	
	// Entspricht 108 Tagen
	int max_zeitschritte <- 4536;
	
	// Debug Zeitschritte zum Testen um Zeit zu sparen
	// int max_zeitschritte <- 100;
	
	// Variablen zur Kontrolle der EPS Population
	int gesamt_eps_gefressen <- 0;
	int gesamt_eps_neues_jahr <- 0;
	
	// Dateiname für Ergebnis CSV
	string filename <- "ergebnisse.csv";
	
	// Benötigter Boolean zur Drchführung der Reproduktion nach Simulationsende
	bool eps_reproduktion_ausgefuehrt <- false;
	
	// Reflex zum aktualisieren der Zeitschritte
	reflex zeitschritt_aktualisieren {
		
		// Raufzählen der Zeitschritte
		aktueller_zeitschritt <- aktueller_zeitschritt + 1;
		
		// Berechnung der simulierten Uhrzeit
		// Laut (Schlicht & Kempenaers, 2020) jagt die Meise 14 Stunden pro Tag bzw. von Sonnenauf- bis -untergang
		// Bei 14 Stunden Jagdzeit entspricht eine Stunde 3 Zeitschritten 
		// 1 Zeitschritt = 20 Minuten
		stunden <- int ((aktueller_zeitschritt mod 42) / 3 + 6);
		minuten <- int (aktueller_zeitschritt mod 3) * 20;
		
		// Neuer Tag startet, wenn 42 zeitschritte erreicht sind
		if (mod(aktueller_zeitschritt, 42) = 0) {
			start <- add_days(start, 1);
			write "Neuer Tag: " + start;
		}
		
		// Hunger nach der Nacht erhöhen ab 06:00 morgens
		if (stunden = 6 and minuten = 0) {
			
			loop einzelne_meise over: meise {
				
				//Hunger erhöhen 
				einzelne_meise.hunger <- min(einzelne_meise.hunger + rnd(3.0, 4.5), 5.0);
				
				// Sättigung der Meise zurücksetzen
				einzelne_meise.satt <- 0; 
			}
		}
		
		if (stunden = 0 and minuten = 0) {
			
			gesamt_eps_gefressen <- 0;
		}
	}
	
	// Simulation beenden, wenn maximale Zeitschritte erreicht sind
	reflex stop_simulation when: aktueller_zeitschritt >= max_zeitschritte or (start > date(2024, 7, 31)) {
		
		write "Simulation pausiert: Maximale Anzahl von " + max_zeitschritte + " Zeitschritten erreicht.";
		do pause;
	}
	
	// Initialisierung der Simulation
	init {
		
		// Prüfen, ob die CSV für Ergebnisse existiert und falls nicht, Header schreiben
		if (!file_exists(filename)) {
			
			write "CSV Datei wird mit Header erstellt";
			
			// Header der CSV Datei
			save ["Baum-ID","EPS Vor Fraß","EPS Nach Fraß","Gefressene EPS","Überlebende Weibchen","EPS Neues Jahr"]  to: filename format: "csv" rewrite: true header:false;
		
		} else {
			
			write "CSV Datei existiert bereits";
		}
		
		// Erstellen der befallenen Bäume
		create befallene_baeume from: befallen;
		
		//Speichert die EPS Population vor dem Fraß
		loop baum over: befallene_baeume {
			
			baum.eps_pop_gesamt <- baum.eps_pop;
			 
		}
		
		// Erstellen der Meisen auf Basis der Nistkastenstandorte
		loop kasten_geometrien over: meisenkaesten {
			
			// Erstellen der ersten Meise des Meisenpaares
			create meise {
				
				location <- point (kasten_geometrien);
				start_location <- point (kasten_geometrien);
				
				// Laut (van Overveld et al., 2011) beträgt der Medianwert des Bewegunsradius der Meise 262 Meter
				// 162 bis 362 Meter zufällig gesetzt, um natürliche Variation zu simulieren
				movement_bounds <- circle (rnd(162, 362), location);
				
			}
			
			// Erstellen der zweiten Meise, um ein Meisenpaar pro Kasten zu simulieren
			create meise {
				
				location <- point (kasten_geometrien);
				start_location <- point (kasten_geometrien);
				
				// Laut (van Overveld et al., 2011) beträgt der Medianwert des Bewegunsradius der Meise 262 Meter
				// 162 bis 362 Meter zufällig gesetzt, um natürliche Variation zu simulieren
				movement_bounds <- circle (rnd(162, 362), location);
				
			}
		}
		
	}
	

	// Species (Agent) für Meisen
	species meise skills: [moving] {
		
		// Startpunkt und Reichweite
		point start_location <- location;
		geometry movement_bounds <- circle (rnd(162, 362), start_location);
		
		// Letzter Baum an dem EPS gefressen wurden
		geometry letzte_eps_quelle <- nil;
		
		// Hungerparamter der Meise (werden im Laufe der Simulation individuell gesetzt)
		float hunger <- 0.0;
		float hunger_rate <- 0.0;
		float hunger_reduktion <- 0.0;
		int satt <- 0;
		int zuletzt_gefundene_nahrung <- 0;
		
		// Reflex zum Update der Flugreichweite
		reflex update_flugreichweite when: aktueller_zeitschritt < max_zeitschritte {
			
			if (zuletzt_gefundene_nahrung > 4) {
				
				// Laut (van Overveld et al., 2011) und (Mathot et al., 2015) erhöhen Meisen die Flugdistanz und das Risiko, sollten sie keine Nahrung aufnehmen
				// Radius der Meise wird vergrößert, wenn sie länger als 4 Zeitschritte nicht gefressen hat
				movement_bounds <- circle(rnd(801, 1440), start_location); 
				// Debug Ausgabe zum Testen, ob der Radius vergrößert wird
				//write "Flugdistanz maximal erhöht (Nahrung zuletzt vor " + zuletzt_gefundene_nahrung + " Zeitschritten)";
			
			} else if (zuletzt_gefundene_nahrung > 2) {
				
				movement_bounds <- circle(rnd(363, 800), start_location);
				//write "Flugdistanz leicht erhöht (Nahrung zuletzt vor " + zuletzt_gefundene_nahrung + " Zeitschritten)";
			
			} else {
				
				movement_bounds <- circle(rnd(162, 363), start_location);
				//write "Flugdistanz normal (Nahrung zuletzt vor " + zuletzt_gefundene_nahrung + " Zeitschritten)";
			}
		}
		
		// Reflex zur Steuerung des Hungers
		reflex hunger_zunahme when: aktueller_zeitschritt < max_zeitschritte {
			
			if (satt > 0) {
				
				satt <- satt - 1;
			
			} else {
				
				// Dynamische Hungerzunahme
				hunger <- min(hunger + hunger_rate * rnd(1.2, 1.5), 5.0);
				// Debug Ausgabe 
				//write "Hunger erhöht: " + hunger + " (Hungerrate: " + hunger_rate + ")";
			}
		} 
		
		// Reflex für Bewgungen und Jagen
		reflex jagen when: aktueller_zeitschritt < max_zeitschritte {
			
			// Die Meise ist zwischen 06:00 und 20:00 aktive
			if (stunden >= 6 and stunden < 20) {
				
				// Variable zum Speicher der aktuellen Amplitude
				float aktuelle_amplitude;
				
				if (hunger < 1.5) {
					
					// Kleine Bewegungssprünge bei wenig Hunger
					aktuelle_amplitude <- 50.0;
				
				} else if (hunger >= 1.5 and hunger <= 3.5) {
					
					// Standard Bewegungssprünge bei mittlerem Hunger
					aktuelle_amplitude <- 100.0;
				
				} else {
					
					// Große Bewegungssprünge bei großem Hunger
					aktuelle_amplitude <- 150.0;
				}
				
				// Gute EPS Quellen können gemerkt werden, aber können um natürliche Variation zu erhöhen, auch vergessen bzw. ignoriert werden
				bool zurueck_zur_eps_quelle <- true;
				
				if (rnd(0.0, 1.0) < 0.3) {
					
					// Ignorieren der Quelle
					zurueck_zur_eps_quelle <- false;
				}
				
				// Laut (Krištín & Kaňuch, 2017) fliegen Meisen mit einer Wahrscheinlichkeit von durchschnittlich 39,1% zurück zur letzten Futterquelle
				if (letzte_eps_quelle != nil and zurueck_zur_eps_quelle and rnd(0.0, 1.0) < 0.391) {
					
					// Laut Dhondt (1966) bewegen sich Meisen mit 20 bis 40 km/h
    				// 20 km/h = 5,55 m/s ; 40km/h = 11,11 m/s
    				do goto(letzte_eps_quelle) speed: rnd(5.56, 11.11);
				
				} else {
					
					do wander amplitude: aktuelle_amplitude speed: rnd(5.56, 11.11) bounds: movement_bounds;
				}
			}
			
			// Aktualisierung des Hungerstatus während der Jagd, da jagen Energie kostet
			if (satt > 0) {
				
				satt <- satt -1;
				
			} else {
				
				hunger <- min(hunger + hunger_rate * rnd(1.5, 2.0), 5.0);
				// Debug Ausgabe
				//write "Hunger erhöht: " + hunger + " (Hungerrate: " + hunger_rate + ")";
			}
		}
		
		// Reflex für die Rückkehr zum Nistkasten, wenn die Jagdzeit vorbei ist
		reflex zurueck_zum_kasten when: stunden = 6 and minuten = 0 {
			
			// Um 06:00 morgens werden alle Meisen zurück auf ihren Nistkastenplatz zurückgesetzt
			location <- start_location;
			// Debug Ausgabe
			// write "Meise startet den neuen Tag am Nistkasten";
		}
		
		// Reflex zum Fressen der EPS 
		reflex eps_fressen when: hunger > 0 and stunden >= 6 and stunden < 20 {
			
			//Debug Ausgabe
			// write "aktueller Hunger der Meise vor dem Fressen: " + hunger;
			
			// Boolean zum Steuern, ob Fressaktivität ausgeführt wurde
			bool gefressen <- false;
			
			// Benötigte Variable zur Berechnung der EPS Reduktion
			float reduktionsfaktor;
			
			// Standardwert für gefressene EPS vor Schleifenbeginn
			int eps_gefressen <- 0;
			
			// Reduktion der Fraßrate basierend auf dem Larvenstadium und Verpuppung
			// Laut (Schmidt et al. 1989) nimmt die Menge der gefressenen EPS mit fortschreitenem Larvenstadium immer weiter ab
			// Vom 15.04. bis 15.05. befinden sich die Larven im L1 und L2 Stadium und werden bevorzugt durch die Meise gefressen
			if ((month(start) = 4) or (month(start) = 5 and day(start) <= 15)) {
				
				reduktionsfaktor <- rnd(0.8, 1.0);
			
			// Ab dem 16.05. beginnt L3. Es bilden sich erste Brennhaare aus und die Meise fängt an, den EPS weniger als Nahrung zu bevorzugen
			} else if (month(start) = 5 and day(start) >= 16) {
				
				reduktionsfaktor <- rnd(0.5, 0.8);
			
			// Ab dem 01.06. beginnt L4 bis L5. Es bilden sich immer mehr Brennhaare und der Fraß durch die Meise wird stark reduziert
			} else if (month(start) = 6) {
				
				reduktionsfaktor <- rnd(0.1, 0.3);
			
			// Ab dem 01.07. beginnt die Verpuppung und es werden fast keine EPS mehr gefressen
			} else if (month(start) = 7) {
				
				reduktionsfaktor <- rnd(0.01, 0.05);

			}
			
			// Die Meise prüft, ob sie sich im Kronendurchmesser des Baumes befinden
			// Befindet sich die Meise im Bereich des Kronendurchmessers, kann sie EPS fressen
			loop baum over: befallene_baeume {
				
				// Prüfen, ob sich die Meise im Kronenradius des Baumes befindet
				if (distance_to(geometry(self), baum.baum_geom) <= (baum.kdr * 0.5)) {
					
					// Wahrscheinlichkeitslogik, EPS zu fressen
					float wahrscheinlichkeit;
					
					// Je größer der Hunger ist, desto höher ist die Wahrscheinlichkeit, EPS zu fressen
					if (hunger <= 2.0) {
						
						// Geringe Wahrscheinlichekit bei wenig Hunger
						wahrscheinlichkeit <- rnd(0.05, 0.15) * reduktionsfaktor;
					
					} else if (hunger > 2.0 and hunger <= 4.0) {
						
						// Moderate Wahrscheinlichkeit bei moderatem Hunger
						wahrscheinlichkeit <- rnd(0.4, 0.6) * reduktionsfaktor;
						
					} else {
						
						// Hohe Wahrscheinlichkeit bei großem Hunger
						wahrscheinlichkeit <- rnd(0.85, 0.9);
						
					}
					
					// Debug Ausgabe
					// write "Meise prüft ob sie im Baum Radius ist. Wahrscheinlichkeit: " + wahrscheinlichkeit;
					
					// Fressen von EPS mit Wahrscheinlichkeit
					// Laut (Perrins, 1991) führen Meisen während der Brutzeit ca. 45 Fütterungen pro Stunde durch
					// Pro Zeitschritt 15 Fütterungen
					// Annahme ist, dass zur Brutzeit 20 bis 40 Prozent der Fütterungen aus EPS besteht
					
					// Vorab prüfen, ob EPS am Baum sind 
					if (baum.eps_pop > 0 and rnd(0.0, 1.0) < wahrscheinlichkeit) {
						
						if (month(start) = 4 or (month(start) = 5 and day(start) <= 15)) {
							
							// Im April und Mai werden mehr EPS gefressen
							// 3 bis 6 basiert auf 20 bis 40 Prozent der 15 Fütterungen pro Zeitschritt
							eps_gefressen <- min(baum.eps_pop, rnd(3,6));
							
						} else if (month(start) = 5 and day(start) >= 16) {
							
							// Nestlinge werden langsam Flügge, daher weniger EPS
							// L3 Stadium beginnt
							eps_gefressen <- min(baum.eps_pop, rnd(2, 3));
							
						} else if (month(start) = 6) {
							
							// Ab Juni kaum noch EPS Fraß
							eps_gefressen <- min(baum.eps_pop, rnd(0, 2));
						
						} else {
							
							// Ab Juli nahezu gar kein EPS Fraß mehr
							eps_gefressen <- min(baum.eps_pop, rnd(0, 1));
						}
						
						// EPS Bestand kann reduziert werden, aber nie unter 0 fallen
						baum.eps_pop <- max(baum.eps_pop - eps_gefressen, 0);
						
						// Vergessen der letzten EPS Quelle, wenn sie nicht mehr lukrativ ist und zu wenig EPS vorhanden sind
						if (baum.eps_pop < 10) {
							
							letzte_eps_quelle <- nil;
						}
						
						// Debug Ausgabe zum Testen, ob Meise EPS Bestand reduziert
						//write "Meise frisst! Baum " + baum.baum_id + ": Vorher: " + (baum.eps_pop + eps_gefressen) + ", Gefressen: " + eps_gefressen + ", Nachher: " + baum.eps_pop;
						
						
						// Aktualisierung des Hungers
						hunger <- max(hunger - (eps_gefressen * hunger_reduktion * rnd(1.0, 1.2)), 0);
						
						// Laut (Chettih et al., 2024) sind Meisen in der Lage, sich Futterquellen zu merken
						// Meise merkt sich Baum als gute EPS Quelle wenn sie dort gefressen hat
						letzte_eps_quelle <- baum.baum_geom;
						
						// Zufälliges Vergessen der EPS Quelle nach erfolgreichem Fraß für mehr natürliche Variation
						// Soll verhindern, dass dieselbe Quelle fixiert wird
						// Mit 20 Prozent Wahrscheinlichkeit wird die Quelle wieder vergessen
						if (rnd(0.0, 1.0) < 0.2) {
							
							letzte_eps_quelle <- nil;
						}
						
						// Je mehr EPS gefressen werden, desto länger ist die Meise bzw Nestlinge satt
						satt <- int(eps_gefressen * rnd(0.4, 0.6));
						
						// Variable zur Bestimmung der Gesamtanzahl der gefressenen EPS
						gesamt_eps_gefressen <- gesamt_eps_gefressen + eps_gefressen;
						
						// Debug Ausgabe
						// write "Meise hat " + eps_gefressen + " EPS gefressen. Neue EPS-Population: " + baum.eps_pop + ". Hunger: " + hunger;
						
						// Laut (Krištín & Kaňuch, 2017) zeigen Meisen soziales Lernverhalten und Nahrungsquellen können an anderen Meisen weitergegeben werden
						// Dynamische Weitergabe-Wahrscheinlichkeit je nach verbleibender EPS Population am Baum
						// Je besser die Futterquelle war, desto eher wird sie mit anderen Meisen geteilt, aber auch weniger gute Futterquellen werden weitergebeben
						// Meisen sind "faul" und fliegen zurück zu bekannten Futterquellen, um Energie zu sparen und ihren Stoffwechsel zu schonen
						float weitergabe_wahrscheinlichkeit <- min(max(baum.eps_pop / 25.0, 0.2), 0.8);
						
						if (gesamt_eps_gefressen > 10 and rnd(0.0, 1.0) < weitergabe_wahrscheinlichkeit) {
							
							loop andere_meise over: meise {
								
								if (distance_to(self, andere_meise) < rnd(162, 363) and rnd(0.0, 1.0) < 0.391) {
									
									andere_meise.letzte_eps_quelle <- baum.baum_geom;
								}
							}
						}
						
						// Sollte die Meise keinen Hunger mehr haben, frisst sie nicht
						// Solange Nestlinge vorhanden sind, werden trotzdem EPS gesammelt
						// Ab Mitte Mai sammelt oder frisst die Meise nicht, sobald sie satt ist 
						if (hunger <= 0) {
							
							if (month(start) >= 6 or (month(start) = 5 and day(start) >= 16)) {
								break;
							
							}
						}
						
						// Wenn die Meise gefressen hat, wird der Zähler auf 0 zurückgesetzt
						zuletzt_gefundene_nahrung <- 0;
					}
				}
			}
			
			// Falls keine EPS gefressen werden, aber dennoch Nahrung aufgenommen wird, wird Alternativnahrung gefressen
			//Wahrscheinlichkeiten für Alternativnahrung je nach Zeitpunkt
			// Je länger die Simulation läuft, desto mehr Bedeutung bekommt Alternativnahrung
			float wirksamkeit_alternativnahrung;
			
			if (month(start) = 4 or (month(start) = 5 and day(start) <= 15)) {
				
				// Alternativnahrung im Frühjahr mit 25 bis 35 Prozent Wahrscheinlichkei, da EPS bevorzugt wird
				wirksamkeit_alternativnahrung <- rnd(0.25, 0.35);
			
			} else if (month(start) = 5 and day(start) > 15) {
				
				// Übergangsphase ab Mitte Mai; 45 bis 55 Prozent Wahrscheinlichkeit für Alternativnahrung
				wirksamkeit_alternativnahrung <- rnd(0.45, 0.55);
				
			} else {
				
				// Ab Juni verstärkt Alternativnahrung
				wirksamkeit_alternativnahrung <- rnd(0.65, 0.75);
			}
			
			// Falls die Meise hungrig ist und nicht frisst, steigt die Wahrscheinlichkeit für alternative Nahrung an, damit sie überhaupt
			if (hunger > 3) {
				wirksamkeit_alternativnahrung <- min(wirksamkeit_alternativnahrung + 0.1, 1.0);
			}
			
			if (hunger > 4) {
				wirksamkeit_alternativnahrung <- min(wirksamkeit_alternativnahrung + 0.2, 1.0);
			}
			
			// Boolean zum Speichern, ob die Meise alternative Nahrung gefressen hat
			bool alternative_nahrung_gefressen <- false;
			
			// Es muss davon ausgegangen werden, dass auch Alternativnahrung (z.B. Spinnen, Insekten etc.) nicht immer verfügbar ist, aber fast immer
			float generelle_nahrungsverfuegbarkeit <- rnd(0.8, 0.95);
			
			// Wenn die Meise keine EPS gefressen hat und bereit ist, Alternativnahrung zu fressen und diese verfügbar ist, dann frisst sie sie auch
			if (!gefressen and rnd(0.0, 1.0) < wirksamkeit_alternativnahrung and rnd(0.0, 1.0) < generelle_nahrungsverfuegbarkeit) {
				
				// Wie bereits erwähnt, 15 Fütterungen pro Zeitschritt
				// 9 bis 12 entspricht 60 bis 80 Prozent der Fütterungen, die nicht aus EPS bestehen
				int andere_nahrung <- rnd(9, 12);
				
				// Alternative Nahrung macht weniger satt als EPS
				hunger <- max(hunger - (andere_nahrung * hunger_reduktion * rnd(0.1, 0.3)), 0);
				
				// Meise bleibt kürzer satt als nach EPS Fraß
				satt <- int(andere_nahrung * rnd(0.05, 0.15));
				
				// Boolean setzen, dass Alternativnahrung gefressen wurde
				alternative_nahrung_gefressen <- true;
				
				// Debug Ausgabe
				// write "Alternative Nahrung gefressen (" + andere_nahrung + " Einheiten). Neuer Hunger: " + hunger;
			}
			
			// Sobald die Meise gefressen hat, egal ob EPS oder Alternativnahrung, wird der Zähler zurückgesetzt
			if (gefressen or alternative_nahrung_gefressen) {
				
				zuletzt_gefundene_nahrung <- 0;
			
			// Wenn die Meise nichts frisst, wird der Zähler hochgezählt
			} else {
				
				zuletzt_gefundene_nahrung <- zuletzt_gefundene_nahrung + 1;
			}
		}
		
		// Darstellung der Meisen falls GUI verwendet werden soll
		aspect base {
			
			if (hunger > 3.5) {
				
				// Sehr hungrige Meisen werden rot dargestellt
				draw triangle(50) color: #red;
			
			} else if (hunger > 2.0 and hunger <= 3.5) {
				
				// Verstärkt hungrige Meisen werden orange dargestellt
				draw triangle(50) color: #orange;
				
			} else if (hunger > 1.0 and hunger <= 2.0) {
				
				// Leicht hungrige Meisen werden gelb dargestellt
				draw triangle(50) color: #yellow;
				
			} else {
				
				// Nicht hungrige Meisen werden grün dargstellet
				draw triangle(50) color: #green;
			}
		}
	}
	
	// Species für Bäume
	species befallene_baeume {
		
		geometry baum_geom <- geometry(self);
		
		// Eindeutige ID für jeden Baum
		int baum_id <- int(self.index);
		
		// Kronendurchmesser zufällig im Bereich von 5,74 bis 14,3 Meter für jeden Baum
		// Werte stamme aus dem Baumkataster der Stadt Gütersloh
		float kdr <- (10.02 + rnd(-4.28, 4.28));
		
		// Eier pro EPS Nest, welche schlüpfen
		// Laut (Lug, 2013) enthält ein Eigelege 100 bis 200 Eier
		int eier_pro_nest <- rnd(100, 200);
		
		// Schlupfrate der Eier
		// Laut (Mirchec et al., 2003) entwicklen sich bzw. schlüpfen 93,2 bis 94,3 Prozent der Eier
		float ueberlebensrate_ei <- rnd(0.932, 0.943);
		
		// Anzahl der NEster pro befallenem Baum
		// Laut (Sobczyk, 2014) befinden sich 10 bis 15 Nester pro Baum
		int nester_pro_baum <- rnd(10, 15);
		
		// Skalierungsfaktor für EPS Population für die Abhängigkeit zur Baumlrone
		float skalierung_kdr <- kdr / 10;
		
		// Berechnung der EPS Population
		int eps_pop <- int(round(eier_pro_nest * nester_pro_baum * skalierung_kdr * ueberlebensrate_ei));
		
		// EPS Population vor dem Fraß durch die Meise
		int eps_pop_gesamt <- eps_pop;
		
		
		// Reflex zur Berechnung der Reproduktion des EPS
		// Wird am Ende der Simulation ausgeführt
		reflex eps_reproduktion when: aktueller_zeitschritt = max_zeitschritte and not eps_reproduktion_ausgefuehrt {
			
			// Boolean der markiert, dass der Reflex ausgeführt wurde
			// Dient zur Erstellung der CSV, da diese sonst städnig durch den Reflex überschrieben wird
			eps_reproduktion_ausgefuehrt <- true;
			
			// Debug Ausgabe
			// write "Reflex eps_reproduktion erfolgreich ausgeführt!";
			
			// Variablen zum Zählen der EPS Nachkommen für das Folgejahr
			gesamt_eps_neues_jahr <- 0;
			int eps_neues_jahr <- 0;
			
			// Sammeln der Daten in Liste
			
			// Liste für die gesammelten Daten 
			list<list> baumdaten <- [];
			
			// Debug Ausgabe
			// Testen, ob die Liste vor dem Füllen tatsächlich leer ist
			// write "Vor dem Füllen: Anzahl gespeicherte Bäume in baumdaten: " + length(baumdaten);
			
			// Loop über jeden einzelnen Baum um später EPS Nachkommen berechnen zu können
			loop baum over: befallene_baeume {
				
				// Laut (Pascual, 1988) beträgt die Geschlechterverteilung Männchen:Weibchen 1:0,59
				// Daraus ergibt sich ein Anteil von 37,11 Prozent Weibchen innerhalb der EPS Population
				float geschlechterverteilung <- 0.3711;
				
				// Anzahl der weiblichen EPS
				int eps_w <- int(eps_pop_gesamt * geschlechterverteilung); 
				
				// Anzahl der gefressenen EPS
				int eps_gefressen <- max(baum.eps_pop_gesamt - baum.eps_pop, 0);
				
				// Holt die Originale EPS Population des Baumes
				int eps_pop_gesamt_vor_frass <- baum.eps_pop_gesamt; 
				
				// Anazahl der überlebenden EPS am Baum nach Fraß durch die Meise
				int eps_gesamt_nach_frass <- baum.eps_pop;
				
				// Anteil der überlebenden Weibchen. Es gilt die Annahme, dass weiterhin 37,11 Prozent der EPS weiblich sind
				int eps_w_ueberlebend <- int(eps_gesamt_nach_frass * geschlechterverteilung);
				
				// Abfangen, dass der Wert der weiblichen überlbenden EPS nicht kleiner 0 werden kann
				if (eps_w_ueberlebend < 0) {
					
					eps_w_ueberlebend <- 0;
				}
				
				// Laut (Gößwein & Lobinger, 2014; Neuberg et al., 2021) legen EPS Weibchen 100 bis 300 Eier
				int eier_pro_weibchen <- rnd(100, 300);
				
				//Laut (Mirchev et al., 2003) entwicklen sich 93,2 bis 94,3 Prozent der Eier
        		//float ueberlebensrate_ei <- rnd(0.932, 0.943);
        		
        		// Berechnung der EPS Nachkommen für das Folgejahr
        		
        		// Berechnung der EPS Nachkommen für das Folgejahr pro Baum
        		eps_neues_jahr <- int(eps_w_ueberlebend * eier_pro_weibchen * ueberlebensrate_ei);
        		
        		// Berechnung der Gesamtanzahl der EPS Nachkommen für das Folgejahr
        		gesamt_eps_neues_jahr <- gesamt_eps_neues_jahr + eps_neues_jahr;
        		
        		// Debug Ausgabe, da CSV anfangs falsche Werte enthielt
        		write "Baum " + baum.baum_id + ": EPS vorher: " + baum.eps_pop_gesamt + ", gefressen: " + eps_gefressen + ", EPS nachher: " + baum.eps_pop;
        		
        		// Hinzufügen der Ergebnisse zur Liste
        		baumdaten <- baumdaten + [[baum.baum_id, eps_pop_gesamt_vor_frass, eps_gesamt_nach_frass, eps_gefressen, eps_w_ueberlebend, eps_neues_jahr]]; 
        
			}
			
			// Debug Ausgabe zum Testen, ob alle Bäume in der Liste erfasst wurden
			// write "Nach dem Füllen: Anzahl gespeicherte Bäume in baumdaten: " + length(baumdaten);
			
			// Wichtig!!! Speichern der gesamten Daten am Ende und nicht innerhalb der Schleife
			loop daten over: baumdaten {
				
				//Speichern der Daten in die ergebnisse.csv
				save daten to: "ergebnisse.csv" format: "csv" rewrite: false;
			}
			
			write "Daten wurden erfolgreich in 'ergebnisse.csv' gespeichert";
			
			// Konsolenausgabe über die Anzahl der EPS Nachkommen für das Folgejahr (vermutlich bei jedem Durchlauf hoch)
			write "Gesamt EPS-Nachkommen für nächstes Jahr: " + gesamt_eps_neues_jahr;
		}
	}
}

experiment "EPS in GT" type: batch;

// Nur aktivieren, falls Simulation über GUI laufen soll
experiment "Meisen vs. EPS in Gütersloh" type: gui {
	
	output {
		
		display map type: opengl {
			
			graphics "Map" {
				
				// Darstellen des Stadtgebietes
				draw stadt_gt_geom color: #grey;
				
				// Darstellen der mit EPS befallenen Bäume
				draw befallen_geom color: #black;
				
				// Darstellen der Meisen Nistkasten Standorte
				draw kasten_geom color: #blue;
			}
			
			// Darstellen der Meisen
			species meise aspect: base;
		}
		
		// Chart um Anzahl der gefressenen EPS zu visualisieren
		display eps_pop_chart {
			
			chart "Gefressen EPS" {
				
				data "Gesamt EPS gefressen" value: gesamt_eps_gefressen color: #green;
			}
		}
	}
}



