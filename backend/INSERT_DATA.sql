-- ============================================================================
-- SQL SKRIPTA ZA UNOS PODATAKA - INSTITUTIONS, GENRES, SHOWS I PERFORMANCES
-- ============================================================================
-- NAPOMENA: Pokrenite ovu skriptu NAKON što primjenite migraciju
-- ============================================================================

USE [210107];
GO

-- ============================================================================
-- KORAK 1: UNOS INSTITUCIJA
-- ============================================================================

PRINT 'Unos institucija...';
PRINT '';

-- Obriši postojeće institucije (ako postoje) da izbjegnemo duplikate i FK probleme
-- VAŽNO: Obriši u pravom redoslijedu zbog FK constraintova!
DELETE FROM Performances;
DELETE FROM Shows;
DELETE FROM Institutions;
PRINT '  ✓ Obrisani postojeći Performances, Shows i Institutions (ako su postojali)';
PRINT '';

-- Koristi IDENTITY_INSERT da forsiraš ID-eve 1-8
SET IDENTITY_INSERT Institutions ON;

-- Narodno pozorište Sarajevo (ID: 1)
INSERT INTO Institutions (Id, Name, Description, Address, Capacity, ImagePath, Website, IsActive, CreatedAt)
VALUES (
    1,
    N'Narodno pozorište Sarajevo',
    N'Narodno pozorište Sarajevo centralna je i najznačajnija teatarska kuća u BiH, u sklopu koje djeluju Drama, Opera i Balet, a pod istim krovom nalazi se i Sarajevska filharmonija.',
    N'Obala Kulina bana 9, 71000 Sarajevo',
    432,
    N'/images/nps.jpg',
    N'https://nps.ba/',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Narodno pozorište Sarajevo';

-- Kamerni teatar 55 (ID: 2)
INSERT INTO Institutions (Id, Name, Description, Address, Capacity, ImagePath, Website, IsActive, CreatedAt)
VALUES (
    2,
    N'Kamerni teatar 55',
    N'Kamerni teatar 55 osnovao je 1955. godine u Sarajevu Jurislav Korenić, kao prostor novog i avangardnog teatarskog izraza, drugačijeg od tada dominantnog pozorišnog modela u Jugoslaviji. Tokom decenija, teatar je izgradio ugled institucije visokih umjetničkih standarda i snažne veze s publikom, nastupajući širom regiona i Evrope. Posebna intimnost scenskog prostora, naročito izražena tokom ratnih devedesetih, učinila je Kamerni teatar 55 simbolom duhovnog otpora i zajedništva.',
    N'Maršala Tita 55/II, 71000 Sarajevo',
    160,
    N'/images/kt.jpg',
    N'https://www.kamerniteatar55.ba/',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Kamerni teatar 55';

-- Sarajevski ratni teatar (ID: 3)
INSERT INTO Institutions (Id, Name, Description, Address, Capacity, ImagePath, Website, IsActive, CreatedAt)
VALUES (
    3,
    N'Sarajevski ratni teatar',
    N'Najmlađa teatarska kuća u Sarajevu, Sarajevski ratni teatar SARTR, osnovana je 1992. godine tokom opsade Sarajeva i danas okuplja mlade teatarske radnike koji svakog mjeseca produciraju nove pozorišne predstave.',
    N'Gabelina 16, 71000 Sarajevo',
    250,
    N'/images/sartr.jpg',
    N'https://sartr.ba/',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Sarajevski ratni teatar';

-- Pozorište mladih Sarajevo (ID: 4)
INSERT INTO Institutions (Id, Name, Description, Address, Capacity, ImagePath, Website, IsActive, CreatedAt)
VALUES (
    4,
    N'Pozorište mladih Sarajevo',
    N'Pozorište mladih Sarajevo, čiji repertoar nudi predstave za djecu, mlade, ali i odrasle, osnovano je 1977. godine udruživanjem Pionirskog pozorišta i Pozorišta lutaka.',
    N'Kulovića 8, 71000 Sarajevo',
    250,
    N'/images/pozm.jpg',
    N'https://pozoristemladih.ba/',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Pozorište mladih Sarajevo';

-- Otvorena scena Obala (ID: 5)
INSERT INTO Institutions (Id, Name, Description, Address, Capacity, ImagePath, Website, IsActive, CreatedAt)
VALUES (
    5,
    N'Otvorena scena Obala',
    N'Otvorena scena Obala je alternativna pozorišna scena nastala pri Akademiji scenskih umjetnosti Sarajevo 1984. godine. Repertoar čine predstave studenata Akademije.',
    N'Obala Kulina bana 11, 71000 Sarajevo',
    130,
    N'/images/os.jpg',
    N'https://www.asu.unsa.ba/',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Otvorena scena Obala';

-- JU Centar kulture i mladih (ID: 6)
INSERT INTO Institutions (Id, Name, Description, Address, Capacity, ImagePath, Website, IsActive, CreatedAt)
VALUES (
    6,
    N'JU Centar kulture i mladih',
    N'Javna ustanova Centar kulture i mladih Općine Centar Sarajevo, osnovana je 1965. godine. Do 1992. godine objedinjavala je rad 13 domova kulture na području današnjih Općina Centar Sarajevo i Stari Grad i sa tridesetak zaposlenih bila jedna od najvećih ustanova ovog umjetničkog profila.',
    N'Jelića 1, 71000 Sarajevo',
    80,
    N'/images/ck.jpg',
    N'https://centarkulture.ba/',
    1,
    GETUTCDATE()
);
PRINT '  ✓ JU Centar kulture i mladih';

-- Bosanski kulturni centar (ID: 7)
INSERT INTO Institutions (Id, Name, Description, Address, Capacity, ImagePath, Website, IsActive, CreatedAt)
VALUES (
    7,
    N'Bosanski kulturni centar',
    N'Bosanski kulturni centar, nekadašnji sefardski hram Templ, nalazi se u centru Sarajeva i predstavlja jedno od najznačajnijih kulturnih zdanja grada. Izgrađen 1930. godine prema projektu Rudolfa Lubinskog, Templ je 1948. godine poklonjen Sarajevu i prilagođen kulturnim potrebama prema projektu Ivana Štrausa. Danas je to savremeni kulturni centar sa koncertnom dvoranom vrhunske akustike i simbolima dugog jevrejskog naslijeđa u Sarajevu.',
    N'Branilaca Sarajeva 24, 71000 Sarajevo',
    800,
    N'/images/bkc.jpg',
    N'https://bkc.ba/',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Bosanski kulturni centar';

-- Dom mladih Skenderija (ID: 8)
INSERT INTO Institutions (Id, Name, Description, Address, Capacity, ImagePath, Website, IsActive, CreatedAt)
VALUES (
    8,
    N'Dom mladih Skenderija',
    N'Dom mladih je multimedijalni prostor u kojem se redovno dešavaju različiti događaji, a koji je prevashodno namijenjen kulturno – umjetničkom stvaralaštvu mladih.',
    N'Terezije bb, 71000 Sarajevo',
    2000,
    N'/images/dm.jpg',
    N'https://skenderija.ba/',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Dom mladih Skenderija';

SET IDENTITY_INSERT Institutions OFF;

PRINT '';
PRINT 'Institucije unesene: 8';
PRINT '';
GO

-- ============================================================================
-- KORAK 2: UNOS ŽANROVA
-- ============================================================================

PRINT 'Unos žanrova...';
PRINT '';

-- Obriši postojeće žanrove (ako postoje) da izbjegnemo duplikate
DELETE FROM Genres;
PRINT '  ✓ Obrisani postojeći žanrovi (ako su postojali)';

-- Koristi IDENTITY_INSERT da forsiraš ID-eve 1-5
SET IDENTITY_INSERT Genres ON;

INSERT INTO Genres (Id, Name, CreatedAt)
VALUES 
    (1, N'Drama', GETUTCDATE()),
    (2, N'Komedija', GETUTCDATE()),
    (3, N'Dječija predstava', GETUTCDATE()),
    (4, N'Balet', GETUTCDATE()),
    (5, N'Opera', GETUTCDATE());

SET IDENTITY_INSERT Genres OFF;

PRINT '  ✓ Drama (ID: 1)';
PRINT '  ✓ Komedija (ID: 2)';
PRINT '  ✓ Dječija predstava (ID: 3)';
PRINT '  ✓ Balet (ID: 4)';
PRINT '  ✓ Opera (ID: 5)';

PRINT '';
PRINT 'Žanrovi uneseni: 5';
PRINT '';
GO

-- ============================================================================
-- KORAK 3: UNOS PREDSTAVA (SHOWS)
-- ============================================================================

PRINT 'Unos predstava...';
PRINT '';

-- Obriši postojeće Shows (ako postoje) - već su obrisani u Institutions sekciji, ali ovdje za sigurnost
DELETE FROM Shows;
PRINT '  ✓ Obrisani postojeći Shows (ako su postojali)';
PRINT '';

-- Koristi IDENTITY_INSERT da forsiraš ID-eve 1-17
SET IDENTITY_INSERT Shows ON;

-- 1. Sarajevo moje drago (InstitutionId: 1, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    1,
    N'Sarajevo moje drago',
    N'"Sarajevo moje drago" je bosanskohercegovački mjuzikl koji će Narodno pozorište u Sarajevu svojoj publici premijerno predstaviti prvih dana ovogodišnje jesenje pozorišne sezone. Ovaj mjuzikl je autorsko djelo Zlatana Fazlića Fazle koji potpisuje libreto i 20 novih muzičkih kompozicija. Priča je originalna, a sve muzičke numere su nove, napravljene ciljano za ovo muzičko-scensko djelo. Aranžmane muzičkih numera napravio je maestro Ranko Rihtman koji će i dirigirati orkestrom Sarajevske filharmonije, a ovaj veliki i zahtjevni muzički i dramski komad režiraće Dino Mustafić. U mjuziklu "Sarajevo moje drago" sudjelovaće velika glumačka ekipa vrhunskih domaćih pozorišnih umjetnika, kao Balet i Hor opere Narodnog pozorišta u Sarajevu.',
    90,
    1,
    1,
    N'/images/sarajevo-moje-drago.jpeg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Sarajevo moje drago (ID: 1)';

-- 2. Marlene Dietrich - Pet tačaka optužnice (InstitutionId: 1, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    2,
    N'Marlene Dietrich - Pet tačaka optužnice',
    N'Marlene Dietrich je bila više od filmske zvijezde – bila je mit. Jedna veoma neobična žena, veoma posebna, koja je u svom životu uvijek pravila nekonvencionalne izbore, često rizikujući reakciju svoje okoline – bilo privatne, profesionalne ili reakciju u svojoj domovini.',
    105,
    1,
    1,
    N'/images/marlene-dietrich-pet-tacaka-optuznice.jpg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Marlene Dietrich - Pet tačaka optužnice (ID: 2)';

-- 3. Na slovo F (InstitutionId: 1, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    3,
    N'Na slovo F',
    N'"Beznađe. Izgubljenost. Potraga za smislom. Vera u ljubav. Čežnja za srećom. Ovo su samo neke od tema o kojima nastojimo da progovorimo kroz predstavu. Nadam se da ćemo uspeti da ukažemo na neprikosnoveni značaj ljubavi, dobrote i razumevanja za drugog, kao i na zlo koje proističe iz predrasuda i okrutnosti." – zapisala je rediteljica Iva Milošević.',
    110,
    1,
    1,
    N'/images/na-slovo-f.jpg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Na slovo F (ID: 3)';

-- 4. Snjeguljica i sedam patuljaka (InstitutionId: 1, GenreId: 4 - Balet)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    4,
    N'Snjeguljica i sedam patuljaka',
    N'Kralj i kraljica dobiše kćerkicu, kože bijele kao snijeg, obraza rumenih kao krv, a kose crne kao gar. Prozvaše je Snjeguljica. Njihova sreća, nažalost nije dugo trajala, jer se kraljica uskoro razboli i umre, a kralj se oženi drugom ženom, koja je bila lijepa, ali ohola i zla. Nije podnosila da iko bude ljepši od nje, a imala je čarobno ogledalo koje joj je odgovaralo na pitanje: "Ko je najljepši u zemlji?". Dok je odgovor bio: "Kraljice, Vi ste najljepši", bila je zadovoljna, ali je živjela u strahu da se situacija ne promijeni.',
    70,
    1,
    4,
    N'/images/snjeguljica-i-sedam-patuljaka.jpeg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Snjeguljica i sedam patuljaka (ID: 4)';

-- 5. ON(A) (InstitutionId: 2, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    5,
    N'ON(A)',
    N'Predstava ON(A) inspirisana je stvarnim životima bračnog para, danskih umjetnika Gerde i Einara Wegenera – kasnije Lili Elbe, transrodne žene i jedne od prvih osoba koja se podvrgnula operaciji promjene spola. Ovo je intimna i snažna priča o bezuslovnoj ljubavi, potrazi za identitetom i hrabrosti da upoznamo i prihvatimo sebe, bez obzira na cijenu koju ta istina nosi.',
    90,
    2,
    1,
    N'/images/ona.jpg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ ON(A) (ID: 5)';

-- 6. Malograđanska svadba (InstitutionId: 2, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    6,
    N'Malograđanska svadba',
    N'Svatovi jedu, piju, govore, plešu samo da ne bi nastala tišina koja je trenutak ozbiljne opasnosti, upravo zbog toga jer može postati trenutak razmišljanja i ujedno trenutak konfrontacije sa samim sobom. Samodestrukcija i opšti raspad je svakako posljedica malograđanskog odsustva tišine...',
    90,
    2,
    1,
    N'/images/malogradjanska-svadba.jpg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Malograđanska svadba (ID: 6)';

-- 7. Otac (InstitutionId: 2, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    7,
    N'Otac',
    N'Cilj nam je da se u pozorištu progovori o društveno neprihvaćenim temama kao što su: suicid, razvod, mentalne bolesti, pozicija žene u porodici, dječija perspektiva na turbulentni svijet, starenje i smrt…',
    90,
    2,
    1,
    N'/images/otac.jpg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Otac (ID: 7)';

-- 8. Ljubavnice (InstitutionId: 2, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    8,
    N'Ljubavnice',
    N'Prema romanu dobitnice Nobelove nagrade za književnost, Elfriede Jelinek, u režiji Jovane Tomić. Jedan od najvažnijih romana austrijske nobelovke Elfriede Jelinek stiže na našu scenu! "Ljubavnice" donose priču o ženama u patrijarhalnom društvu, njihovim borbama sa društvenim normama, ljubavlju i nemilosrdnim kapitalizmom. Brigita, Paula i Suzi vode vas u svijet gdje je sve rad, a ljubav – možda samo još jedan oblik teškog rada. Da li je moguće pronaći slobodu i smisao u svijetu koji sve podređuje profitu? Otkrijte odgovore u ovoj provokativnoj i emotivnoj predstavi koja će vas potaknuti na razmišljanje.',
    90,
    2,
    1,
    N'/images/ljubavnice.jpg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Ljubavnice (ID: 8)';

-- 9. Totovi (InstitutionId: 3, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    9,
    N'Totovi',
    N'Komad je groteska sa elementima satire, koji je Ištvan Erkenj, jedan od najpriznatijih mađarskih pisaca 20. veka napisao na osnovu novele "Dobrodošlica za Majora" iz 1966. godine. Inspirisana je stravičnom, istovremeno besmislenom i uzaludnom, sudbinom mađarskih vojnika na Istočnom frontu januara 1943.',
    100,
    3,
    1,
    N'/images/totovi.webp',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Totovi (ID: 9)';

-- 10. Za život cijeli (InstitutionId: 3, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    10,
    N'Za život cijeli',
    N'Sama činjenica da je "Za život cijeli" predstava o nogometnom klubu, o povijesti nogometa u gradu Sarajevu, o 103 godine historije grada Sarajeva i FK Željezničar čini je jedinstvenom u teatarskom životu BiH, regiona i svijeta.',
    80,
    3,
    1,
    N'/images/za-zivot-cijeli.jpg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Za život cijeli (ID: 10)';

-- 11. Njih više nema (InstitutionId: 3, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    11,
    N'Njih više nema',
    N'Poslije više od četiri godine umjetničkog istraživačkog procesa, nastaje nova predstava koja koristeći hibridne teatarske forme ispituje pitanje odgovornosti, zaborava i solidarnosti. Ovaj komad preispituje poziciju svih nas u publici – kako razumijemo i odnosimo se prema onima koji su preživjeli genocid u Srebrenici.',
    95,
    3,
    1,
    N'/images/njih-vise-nema.webp',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Njih više nema (ID: 11)';

-- 12. Podroom (InstitutionId: 3, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    12,
    N'Podroom',
    N'Predstava istražuje klimave temelje i mehanizme ljudskih odnosa u vremenu nesigurnosti, u kojem se intenzivni odnosi stvaraju i raspadaju u sve kraćim vremenskim razmacima.',
    90,
    3,
    1,
    N'/images/podroom.webp',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Podroom (ID: 12)';

-- 13. Ne daj se generacijo (InstitutionId: 4, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    13,
    N'Ne daj se generacijo',
    N'Radnja prati priču o dvije prijateljice koje su nerazdvojene dugi niz godina. Tekst u osnovici tretira temu prijateljstva. Svakodnevnica i preživljavanje uz stereotipne, nametnute forme osobama treće dobi. Želja za iskorakom, neprihvatanjem standardizovanih obrazaca junakinje ove priče odvodi na novo i nepoznato putovanje. Odbijanjem konvecionalnosti dolaze do iskustava koje ih mijenjaju i život čine uzbudljivijim. Upuštaju se u avanture koje im omogućavaju iznenađenja. Otkrivaju život za kakav su mislile da je iza njih.',
    60,
    4,
    1,
    N'/images/ne-daj-se-generacijo.jpg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Ne daj se generacijo (ID: 13)';

-- 14. Cvrčak i mrav (InstitutionId: 4, GenreId: 3 - Dječija predstava)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    14,
    N'Cvrčak i mrav',
    N'Ova izuzetno poučna basna godinama oplemenjuje mnoge pozorišne repertoare. Zbog svoje aktuelnosti i univerzalnosti našla je mjesto i na repertoaru našeg pozorišta. Pričao je to o prijateljstvu, igri, zabavi i radu u kojoj likovi Cvrčka i Mrava predstavljaju ravnotežu između duhovnih i materijalnih vrijednosti potrebnih svakom živom biću. Pjesme i snovi osnovni su motivi ove predstave u kojoj likovi sanjaju sunce, prirodu i ljeto, oni u stvari žele da budu veseli i sretni. Glavni junak ove priče Cvrčak svojom muzikom budi cvjetove i miri različite svjetove, njegova muzika postaje čarobna tajna i ljepota sjajna. Kroz lepršavu i razigranu igru na sceni, songove, živopisnu scenografiju i kostime Pozorište mladih ovom predstavom će sigurno zaintrigirati najmlađu publiku, zabaviti ih i educirati, a stariju publiku "vratiti" u djetinjstvo i sjetiti ih na vrijeme kad su bili djeca- Adis Bakrač',
    60,
    4,
    3,
    N'/images/cvrcek-i-mrav.jpg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Cvrčak i mrav (ID: 14)';

-- 15. DOVIĐENJA (InstitutionId: 4, GenreId: 1 - Drama)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    15,
    N'DOVIĐENJA',
    N'Tema odlaska mladih u potrazi za boljim životom izuzetno je relevantna za Bosnu i Hercegovinu, koja se već godinama suočava s problemom masovnih migracija. Predstava koristi univerzalni jezik teatra da ispriča priču koja pogađa mnoge porodice u našoj domovini, dok istovremeno povezuje lokalne probleme s globalnim izazovima kao što su klimatske promjene i društvena nestabilnost. Kroz inovativnu postavku i emotivno nabijenu priču, projekt ima potencijal, ne samo da privuče publiku, već i da pokrene šire diskusije o budućnosti mladih i održivosti naše planete',
    60,
    4,
    1,
    N'/images/dovidjenja.jpg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ DOVIĐENJA (ID: 15)';

-- 16. TAJNI DNEVNIK ADRIANA MOLEA (InstitutionId: 4, GenreId: 3 - Dječija predstava)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    16,
    N'TAJNI DNEVNIK ADRIANA MOLEA',
    N'Tajni dnevnik Adriana Molea je predstava namjenjena teenagerima, ali još više odraslima. To je ispovjest pubertetlije, ali i kolektivno povjeravanje svih onih koji čine ovu priču i predstavu. Tajni dnevnik je glavni junak. Govori nam o važnosti samosvijesti i povjeravanja. O značaju i hrabrosti čina da budeš potpuno otvoren.',
    90,
    4,
    3,
    N'/images/tajni-dnevnik-adriana-molea.jpeg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ TAJNI DNEVNIK ADRIANA MOLEA (ID: 16)';

-- 17. Patrolne šape (InstitutionId: 8, GenreId: 3 - Dječija predstava)
INSERT INTO Shows (Id, Title, Description, DurationMinutes, InstitutionId, GenreId, ImagePath, IsActive, CreatedAt)
VALUES (
    17,
    N'Patrolne šape',
    N'Predstava je rađena prema, trenutno najpopularnijoj crtanoj TV seriji "Patrolne šape". Puna je zapleta, uzbudljiva, edukativna, intraktivna, a govori o ljubavi, prijateljstvu, snalažljivosti, iskrenosti, borbi između dobra i zla, timskom radu i uzornom ponašanju.',
    60,
    8,
    3,
    N'/images/patrolne-sape.jpg',
    1,
    GETUTCDATE()
);
PRINT '  ✓ Patrolne šape (ID: 17)';

SET IDENTITY_INSERT Shows OFF;

PRINT '';
PRINT 'Predstave unesene: 17';
PRINT '';
GO

-- ============================================================================
-- KORAK 4: UNOS TERMINA IZVOĐENJA (PERFORMANCES)
-- ============================================================================

PRINT 'Unos termina izvođenja...';
PRINT '';

-- Performance za "Sarajevo moje drago" (ShowId: 1, Institution Capacity: 432)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (1, '2026-01-09 19:30:00', 40.00, 432, GETUTCDATE());
PRINT '  ✓ Performance ID: 1 - Sarajevo moje drago (2026-01-09 19:30)';

INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (1, '2026-01-10 19:30:00', 20.00, 432, GETUTCDATE());
PRINT '  ✓ Performance ID: 2 - Sarajevo moje drago (2026-01-10 19:30)';

-- Performance za "Marlene Dietrich" (ShowId: 2, Institution Capacity: 432)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (2, '2026-01-12 19:30:00', 20.00, 432, GETUTCDATE());
PRINT '  ✓ Performance ID: 3 - Marlene Dietrich (2026-01-12 19:30)';

-- Performance za "Na slovo F" (ShowId: 3, Institution Capacity: 432)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (3, '2026-01-13 19:30:00', 10.00, 432, GETUTCDATE());
PRINT '  ✓ Performance ID: 4 - Na slovo F (2026-01-13 19:30)';

-- Performance za "Snjeguljica i sedam patuljaka" (ShowId: 4, Institution Capacity: 432)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (4, '2026-01-14 19:30:00', 10.00, 432, GETUTCDATE());
PRINT '  ✓ Performance ID: 5 - Snjeguljica (2026-01-14 19:30)';

INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (4, '2026-01-15 19:30:00', 10.00, 432, GETUTCDATE());
PRINT '  ✓ Performance ID: 6 - Snjeguljica (2026-01-15 19:30)';

-- Performance za "ON(A)" (ShowId: 5, Institution Capacity: 160)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (5, '2026-01-09 20:00:00', 20.00, 160, GETUTCDATE());
PRINT '  ✓ Performance ID: 7 - ON(A) (2026-01-09 20:00)';

INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (5, '2026-01-10 20:00:00', 20.00, 160, GETUTCDATE());
PRINT '  ✓ Performance ID: 8 - ON(A) (2026-01-10 20:00)';

-- Performance za "Malograđanska svadba" (ShowId: 6, Institution Capacity: 160)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (6, '2026-01-12 20:00:00', 20.00, 160, GETUTCDATE());
PRINT '  ✓ Performance ID: 9 - Malograđanska svadba (2026-01-12 20:00)';

-- Performance za "Otac" (ShowId: 7, Institution Capacity: 160)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (7, '2026-01-13 20:00:00', 20.00, 160, GETUTCDATE());
PRINT '  ✓ Performance ID: 10 - Otac (2026-01-13 20:00)';

-- Performance za "Ljubavnice" (ShowId: 8, Institution Capacity: 160)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (8, '2026-01-14 20:00:00', 20.00, 160, GETUTCDATE());
PRINT '  ✓ Performance ID: 11 - Ljubavnice (2026-01-14 20:00)';

-- Performance za "Totovi" (ShowId: 9, Institution Capacity: 250)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (9, '2026-01-08 20:00:00', 12.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 12 - Totovi (2026-01-08 20:00)';

-- Performance za "Za život cijeli" (ShowId: 10, Institution Capacity: 250)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (10, '2026-01-10 20:00:00', 12.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 13 - Za život cijeli (2026-01-10 20:00)';

INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (10, '2026-01-11 20:00:00', 12.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 14 - Za život cijeli (2026-01-11 20:00)';

-- Performance za "Njih više nema" (ShowId: 11, Institution Capacity: 250)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (11, '2026-01-13 20:00:00', 12.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 15 - Njih više nema (2026-01-13 20:00)';

INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (11, '2026-01-14 20:00:00', 12.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 16 - Njih više nema (2026-01-14 20:00)';

INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (11, '2026-01-15 20:00:00', 12.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 17 - Njih više nema (2026-01-15 20:00)';

-- Performance za "Podroom" (ShowId: 12, Institution Capacity: 250)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (12, '2026-01-17 20:00:00', 12.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 18 - Podroom (2026-01-17 20:00)';

-- Performance za "Ne daj se generacijo" (ShowId: 13, Institution Capacity: 250)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (13, '2026-01-08 20:00:00', 20.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 19 - Ne daj se generacijo (2026-01-08 20:00)';

INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (13, '2026-01-09 20:00:00', 20.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 20 - Ne daj se generacijo (2026-01-09 20:00)';

-- Performance za "Cvrčak i mrav" (ShowId: 14, Institution Capacity: 250)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (14, '2026-01-11 11:00:00', 20.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 21 - Cvrčak i mrav (2026-01-11 11:00)';

-- Performance za "DOVIĐENJA" (ShowId: 15, Institution Capacity: 250)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (15, '2026-01-11 20:00:00', 20.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 22 - DOVIĐENJA (2026-01-11 20:00)';

-- Performance za "TAJNI DNEVNIK ADRIANA MOLEA" (ShowId: 16, Institution Capacity: 250)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (16, '2026-01-13 19:00:00', 20.00, 250, GETUTCDATE());
PRINT '  ✓ Performance ID: 23 - TAJNI DNEVNIK ADRIANA MOLEA (2026-01-13 19:00)';

-- Performance za "Patrolne šape" (ShowId: 17, Institution Capacity: 2000)
INSERT INTO Performances (ShowId, StartTime, Price, AvailableSeats, CreatedAt)
VALUES (17, '2026-01-11 14:00:00', 20.00, 2000, GETUTCDATE());
PRINT '  ✓ Performance ID: 24 - Patrolne šape (2026-01-11 14:00)';

PRINT '';
PRINT 'Termini izvođenja uneseni: 24';
PRINT '';
GO

-- ============================================================================
-- PROVJERA
-- ============================================================================

PRINT '============================================================================';
PRINT 'PROVJERA UNESENIH PODATAKA:';
PRINT '============================================================================';
PRINT '';

PRINT 'INSTITUCIJE:';
SELECT Id, Name, Capacity, Website FROM Institutions ORDER BY Id;

PRINT '';
PRINT 'ŽANROVI:';
SELECT Id, Name FROM Genres ORDER BY Id;

PRINT '';
PRINT 'PREDSTAVE:';
SELECT Id, Title, InstitutionId, GenreId, ImagePath FROM Shows ORDER BY Id;

PRINT '';
PRINT 'TERMINI IZVOĐENJA:';
SELECT Id, ShowId, StartTime, Price, AvailableSeats FROM Performances ORDER BY ShowId, StartTime;

PRINT '';
PRINT '============================================================================';
PRINT 'UNOS ZAVRŠEN!';
PRINT '';
PRINT 'SAŽETAK:';
PRINT '  - Institucije: 8';
PRINT '  - Žanrovi: 5';
PRINT '  - Predstave: 17';
PRINT '  - Termini izvođenja: 24';
PRINT '============================================================================';
GO
