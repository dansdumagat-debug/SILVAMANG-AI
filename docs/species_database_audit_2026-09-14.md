# SILVAMANG AI Species Database and CNN Class Audit

**Audit date:** 2026-09-14  
**Scope:** local `silvamang_ai` MySQL database, Laravel seed data, Flutter offline education data, CNN class-order files, and raw image folders  
**Change status:** **PANEL SELECTION IMPLEMENTED AND LOCALLY VERIFIED**  

This file preserves the pre-change audit. The final confirmed target is **30 total species**: the original 10 CNN species plus all 20 missing species selected from the supplied list. The implementation also standardizes the existing *Avicennia marina* var. *rumphiana* record to *Avicennia rumphiana* and retains the 10-class CNN unchanged.

The selected additions are *Acanthus ebracteatus*, *Acanthus ilicifolius*, *Acanthus volubilis*, *Avicennia alba*, *Avicennia officinalis*, *Nypa fruticans*, *Lumnitzera racemosa*, *Lumnitzera littorea*, *Pemphis acidula*, *Sonneratia ovata*, *Camptostemon philippinensis*, *Heritiera littoralis*, *Xylocarpus rumphii*, *Osbornia octodonta*, *Aegiceras corniculatum*, *Aegiceras floridum*, *Bruguiera cylindrica*, *Bruguiera sexangula*, *Ceriops zippeliana*, and *Scyphiphora hydrophylacea*.

The implemented target is 30 active unique species, 30 education records, 20 new species-specific assistant entries, 10 CNN-supported species, and 20 guide-only species. The local raw dataset and all active class-order files remain at 10 classes.

## Executive Decision

- The current database contains **10 active species**, with **10 unique scientific names** and no soft-deleted species.
- The live education table contains **10 records covering all 10 species**.
- All three active CNN label sources contain the same **10 classes in the same order**.
- The raw CNN folder contains **3,138 image files**, but class totals are imbalanced and only **1 image is represented in `image_manifest.csv`**.
- The species distribution table has 3 rows per species, but the seeder explicitly labels them as **demo placeholders**, so they must not be presented as verified ecological ranges.
- This report recommends **20 missing woody or palm mangrove species** for an additive database and education expansion.
- The 20 species must initially be marked **knowledge-base/field-guide supported, not CNN-supported**. They must not be appended to active class-order files until a new model is trained and exported with matching outputs.

## Audit Method

The following sources were compared:

1. Live MySQL tables: `species`, `mangrove_education`, `mangrove_knowledge`, and `species_distributions`.
2. Laravel seeders: `SpeciesSeeder.php`, `MangroveEducationSeeder.php`, and `MangroveKnowledgeSeeder.php`.
3. Flutter offline educational file: `silvamang_mobile/assets/data/mangrove_education.json`.
4. CNN label files:
   - `dataset/labels/species_labels.txt`
   - `silvamang_ai_service/models/cnn_classifier/class_order.json`
   - `silvamang_mobile/assets/models/class_order.json`
5. Raw image directories under `dataset/raw` and dataset metadata files.
6. Current Philippine and international botanical references listed in the References section.

## CURRENT DATABASE STATUS

### Existing Species

| DB ID | Scientific name stored in SILVAMANG | Common name | Family | Stored status | CNN class | Raw images |
| ---: | --- | --- | --- | --- | --- | ---: |
| 4 | *Avicennia marina* | Grey Mangrove | Acanthaceae | Least Concern | `Avicennia_marina` | 445 |
| 5 | *Avicennia marina* var. *rumphiana* | Api-api / gray mangrove variety | Acanthaceae | Least Concern | `Avicennia_marina_var_rumphiana` | 81 |
| 7 | *Bruguiera gymnorrhiza* | Large-leaved Orange Mangrove | Rhizophoraceae | Least Concern | `Bruguiera_gymnorrhiza` | 428 |
| 8 | *Ceriops tagal* | Tangal | Rhizophoraceae | Least Concern | `Ceriops_tagal` | 293 |
| 9 | *Excoecaria agallocha* | Blind-your-eye mangrove / milky mangrove | Euphorbiaceae | Least Concern | `Excoecaria_agallocha` | 286 |
| 1 | *Rhizophora apiculata* | Red Mangrove | Rhizophoraceae | Least Concern | `Rhizophora_apiculata` | 356 |
| 2 | *Rhizophora mucronata* | Red Mangrove | Rhizophoraceae | Least Concern | `Rhizophora_mucronata` | 369 |
| 3 | *Rhizophora stylosa* | Stilted mangrove / loop-root mangrove | Rhizophoraceae | Least Concern | `Rhizophora_stylosa` | 389 |
| 6 | *Sonneratia alba* | Milky Mangrove | Lythraceae | Least Concern | `Sonneratia_alba` | 375 |
| 10 | *Xylocarpus granatum* | Cannonball Mangrove | Meliaceae | Vulnerable | `Xylocarpus_granatum` | 116 |

### CNN Class Order

The dataset, API service, and Flutter app all use this identical order:

```text
0  Avicennia_marina
1  Avicennia_marina_var_rumphiana
2  Bruguiera_gymnorrhiza
3  Ceriops_tagal
4  Excoecaria_agallocha
5  Rhizophora_apiculata
6  Rhizophora_mucronata
7  Rhizophora_stylosa
8  Sonneratia_alba
9  Xylocarpus_granatum
```

The plant-part labels are `leaves`, `bark`, `roots`, `flowers`, `canopy`, `full_tree`, and `other`. The YOLO label list omits `other`.

### Education, Knowledge, and Distribution Coverage

| Area | Audit result | Risk |
| --- | --- | --- |
| Species education | 10 rows, 10 distinct species IDs | Complete for current species |
| Flutter offline education | 10 entries | Complete for current species |
| Live general knowledge base | 8 rows; only 1 species-specific row | Too little species-specific coverage |
| Knowledge seeder | Defines 15 rows | Live database and seeder are not synchronized |
| Species distributions | 30 rows; 3 per species | Seeder says they are demo placeholders, not verified observations |
| Raw images | 3,138 files | Strong imbalance: 81 to 445 images per class |
| Image manifest | 1 populated row | Provenance, permission, quality, and split metadata are almost entirely missing |

### Existing Record Completeness

All 10 current species records are missing `genus`, `description`, `distribution_notes`, `ecological_role`, and `max_height_m`. Their identification notes mainly identify the associated CNN label instead of providing field characters. The separate education records partly compensate for this, but the core species API can still return sparse fallback profiles.

### Existing Taxonomy and Status Findings

These are audit findings only. They have not been changed.

1. **Do not add *Avicennia rumphiana* as a second species.** The current *Avicennia marina* var. *rumphiana* record represents the same taxon. Co's Digital Flora treats it at species rank, while Kew accepts the varietal name. Use aliases, not two records.
2. **Conservation review needed:** the current *A. marina* var. *rumphiana* record says Least Concern, while the IUCN-linked treatment for the same taxon reports Vulnerable.
3. **Spelling review needed, but no automatic rename:** Kew and Co's Digital Flora currently use *Bruguiera gymnorhiza*. SILVAMANG and its trained class use `gymnorrhiza`. Renaming the active label without an alias migration could break historical predictions.
4. **Conservation review needed:** the current *Xylocarpus granatum* record says Vulnerable, while Kew, IUCN, and Co's Digital Flora report Least Concern globally.
5. **Do not add Philippine records under old names without review:** older guides use *Ceriops decandra* and *Xylocarpus moluccensis*. Current Philippine treatments support *Ceriops zippeliana* and *Xylocarpus rumphii* for the corresponding Philippine material.

## MISSING SPECIES RECOMMENDED

All names below were absent from the live species table, Laravel species seeder, Flutter education JSON, and all active CNN class lists at audit time.

| # | Recommended scientific name | Family | Type | Conservation information | Public image-pool outlook |
| ---: | --- | --- | --- | --- | --- |
| 1 | *Aegiceras corniculatum* | Primulaceae | True mangrove | Global LC | High |
| 2 | *Aegiceras floridum* | Primulaceae | True mangrove | Global NT | Medium |
| 3 | *Avicennia alba* | Acanthaceae | True mangrove | Global LC | High |
| 4 | *Avicennia officinalis* | Acanthaceae | True mangrove | Global LC | High |
| 5 | *Bruguiera cylindrica* | Rhizophoraceae | True mangrove | Global LC | High |
| 6 | *Bruguiera parviflora* | Rhizophoraceae | True mangrove | Global LC | Medium-High |
| 7 | *Bruguiera sexangula* | Rhizophoraceae | True mangrove | Global LC | High |
| 8 | *Camptostemon philippinensis* | Malvaceae | True mangrove | Global EN; DENR EN | Low-Medium |
| 9 | *Ceriops zippeliana* | Rhizophoraceae | True mangrove | Global LC; locally rare | Low |
| 10 | *Heritiera littoralis* | Malvaceae | Mangrove associate/minor mangrove | Global LC | High |
| 11 | *Kandelia candel* | Rhizophoraceae | True mangrove | Global LC; DENR CR | Low-Medium |
| 12 | *Lumnitzera littorea* | Combretaceae | True mangrove | Global LC | Medium-High |
| 13 | *Lumnitzera racemosa* | Combretaceae | True mangrove | Global LC | High |
| 14 | *Nypa fruticans* | Arecaceae | True mangrove palm | Global LC | High |
| 15 | *Osbornia octodonta* | Myrtaceae | True mangrove | Global LC | Medium |
| 16 | *Pemphis acidula* | Lythraceae | True/high-shore mangrove | Global LC; DENR EN | Medium-High |
| 17 | *Scyphiphora hydrophylacea* | Rubiaceae | True mangrove | Global LC | Medium-High |
| 18 | *Sonneratia caseolaris* | Lythraceae | True mangrove | Global LC | High |
| 19 | *Sonneratia ovata* | Lythraceae | True mangrove | Global NT; locally rare | Medium |
| 20 | *Xylocarpus rumphii* | Meliaceae | Coastal mangrove/minor mangrove | Global LC | Medium |

`LC` = Least Concern, `NT` = Near Threatened, `EN` = Endangered, and `CR` = Critically Endangered. Global and Philippine national categories are not interchangeable and should be stored separately in a future schema improvement.

**Important image note:** "High" does not mean training-ready. The local dataset has **zero images for every proposed class**. The rating only describes the likely candidate pool in illustrated floras, herbaria, biodiversity portals, and future field collection. Every image still needs license verification, duplicate removal, expert species confirmation, plant-part labeling, and geographic/source balancing.

## REASON FOR ADDITION AND SPECIES PROFILES

### 1. *Aegiceras corniculatum*

**Scientific name:** *Aegiceras corniculatum* (L.) Blanco  
**Common name:** River mangrove; saging-saging  
**Family:** Primulaceae  
**Description:** A small evergreen mangrove tree or shrub that is widespread in Philippine sheltered coasts and tidal waterways.

**Key identification characteristics:** Leaves are alternate, leathery, obovate to elliptic, usually rounded or slightly notched, and may show salt crystals. Roots are shallow, spreading surface roots. Bark is smooth gray to brown and lenticellate. Flowers are small, fragrant, white, and grouped in rounded clusters. Fruits are curved, horn-like cylinders; the seed begins germinating inside the intact fruit while attached to the tree (cryptovivipary).

**Ecological information:** It stabilizes creek banks, traps sediment, and contributes cover and organic matter to estuarine food webs. It occurs from India through Southeast Asia to the western Pacific, including many Philippine islands. It is most typical of sheltered middle to upper intertidal mud and tidal-creek margins. Global status: Least Concern.

**Educational information:** Linnaeus published the basionym in 1754, and Francisco Manuel Blanco published the accepted combination in 1837. The genus name and curved fruit are commonly associated with a "goat horn" shape. It is useful for teaching cryptovivipary and salt-crystal field clues.

**Reason for addition:** It adds a missing, common Philippine genus and is important for distinguishing horn-like fruits from *Aegiceras floridum*. It supports lessons on estuarine zonation and reproductive adaptation. Public candidate images are relatively abundant in Co's Digital Flora, SEAFDEC guides, biodiversity portals, and herbarium collections, so CNN expansion potential is **High** after curation.

**References:** [SEAFDEC-2004], [CDFP-Primulaceae], [FAO-2007].

### 2. *Aegiceras floridum*

**Scientific name:** *Aegiceras floridum* Roem. & Schult.  
**Common name:** Flowering mangrove; tinduk-tindukan; saging-saging  
**Family:** Primulaceae  
**Description:** A small Malesian mangrove, often only 3-4 m tall, with a more restricted range than *A. corniculatum*.

**Key identification characteristics:** Leaves are small, leathery, obovate, and may carry salt crystals. Surface roots spread through the substrate. Bark is dark brown, mottled, and lenticellate. White flowers occur on branched stalks. Fruits are small, slightly curved, bright red at maturity, and cryptoviviparous.

**Ecological information:** It occupies salt-exposed rocky or sandy mangrove margins and high intertidal sites, often with *Osbornia octodonta* and *Pemphis acidula*. Its range is centered in Malesia and includes the Philippines. Its restricted occurrence makes it useful in site-quality and biodiversity surveys. Global status: Near Threatened.

**Educational information:** The name was published in 1819. Its red fruit, smaller leaves, and branched flower stalks provide a practical comparison with *A. corniculatum*. Philippine field guides document it in Panay, Guimaras, Palawan, and other islands.

**Reason for addition:** It represents a conservation-relevant Philippine true mangrove and prevents students from forcing two *Aegiceras* species into one label. It is useful for high-shore ecology and comparative identification. Illustrated Philippine records and herbarium specimens exist, but its narrower range limits volume; CNN candidate availability is **Medium**.

**References:** [SEAFDEC-2004], [CDFP-Primulaceae], [POWO-Aegiceras-floridum].

### 3. *Avicennia alba*

**Scientific name:** *Avicennia alba* Blume  
**Common name:** White mangrove; api-api  
**Family:** Acanthaceae  
**Description:** A medium to tall pioneer mangrove of muddy seaward margins and river deltas.

**Key identification characteristics:** Leaves are opposite, narrow-oblong to lanceolate, sharply pointed, glossy green above, and pale beneath. Numerous pencil-like pneumatophores rise around the tree. Bark is dark brown to blackish and relatively smooth on younger trunks. Flowers are small and yellow to orange in clusters. Fruits are flattened egg-shaped to pear-shaped, broad at the base, and end in a distinct beak.

**Ecological information:** As a seaward pioneer it traps fine sediment, reduces wave energy, and creates substrate for later mangrove succession. It ranges across South and Southeast Asia to northern Australia and occurs in Philippine muddy shores and deltas. Zonation is generally lower to middle intertidal. Global status: Least Concern.

**Educational information:** Blume published the name in 1826. It is an excellent teaching species for comparing the narrow, pointed leaves and pointed fruits of *A. alba* with the broader leaves of *A. officinalis* and the current *A. marina* classes.

**Reason for addition:** It fills a major gap in the current *Avicennia* coverage and is visually important because it can be confused with existing classes. It supports research on pioneer succession and sediment capture. Public photographs and occurrence images are common; CNN candidate availability is **High**.

**References:** [SEAFDEC-2004], [CDFP-Acanthaceae], [FAO-2007].

### 4. *Avicennia officinalis*

**Scientific name:** *Avicennia officinalis* L.  
**Common name:** Indian mangrove; api-api  
**Family:** Acanthaceae  
**Description:** A broad-leaved *Avicennia* of more landward, riverine, and lower-salinity mangrove habitat.

**Key identification characteristics:** Leaves are opposite, thick, broadly elliptic to obovate, rounded at the tip, dark above, and yellow-green to grayish and finely hairy beneath. Pencil pneumatophores are common, with occasional low supporting roots. Bark is yellowish-green to gray-brown, smooth to lightly fissured, and lenticellate. Flowers are comparatively large, orange-yellow, and hairy. Fruits are broad-ovate, shortly beaked, and hairy.

**Ecological information:** It stabilizes inner riverbanks and adds structural diversity in mature mangrove stands. It is distributed from South Asia through Southeast Asia and occurs in Philippine firm mud along inland mangrove riverbanks. Zonation is middle to upper/interior mangrove, generally less seaward than *A. alba*. Global status: Least Concern.

**Educational information:** Linnaeus published the species in 1753. The epithet `officinalis` often indicates a plant historically associated with medicinal preparation, although SILVAMANG should present traditional-use claims as history, not medical advice.

**Reason for addition:** It improves identification among similar Philippine *Avicennia* species and teaches salinity/zonation differences. Its broad leaves and hairy flowers/fruits offer useful multi-part CNN features. Public image availability is **High**.

**References:** [SEAFDEC-2004], [CDFP-Acanthaceae], [FAO-2007].

### 5. *Bruguiera cylindrica*

**Scientific name:** *Bruguiera cylindrica* (L.) Blume  
**Common name:** Small-leafed orange mangrove; pototan; busain  
**Family:** Rhizophoraceae  
**Description:** A medium-sized true mangrove that can form stands on firm mud in sheltered estuaries.

**Key identification characteristics:** Leaves are opposite, glossy, elliptic, and pointed. Roots form knee-like loops and short buttresses. Bark is gray and smooth to finely fissured. Flowers commonly occur in small clusters, with a greenish calyx of about eight lobes and white, bristled petals. Propagules are thin, smooth, cylindrical, and commonly about 8-15 cm long.

**Ecological information:** Dense roots consolidate mud, while litter contributes nutrients and habitat complexity. The species is widespread from South Asia through Malesia to northern Australia and occurs in Philippine mangrove swamps. It generally occupies sheltered middle intertidal firm clay or mud, often behind pioneer species. Global status: Least Concern.

**Educational information:** Linnaeus first described the taxon under *Rhizophora* in 1753; Blume transferred it to *Bruguiera* in 1827. Its clustered flowers and slender propagules are useful characters for separating it from other *Bruguiera* species.

**Reason for addition:** The current system has only one *Bruguiera* class, so this common species is a likely real-world source of false positives. It supports comparative root, flower, and propagule lessons. Public image availability is **High**, but expert review is needed because online images are often mislabeled among *Bruguiera* species.

**References:** [SEAFDEC-2004], [CDFP-Rhizophoraceae], [FAO-2007].

### 6. *Bruguiera parviflora*

**Scientific name:** *Bruguiera parviflora* (Roxb.) Wight & Arn. ex Griff.  
**Common name:** Small-flowered orange mangrove; langarai  
**Family:** Rhizophoraceae  
**Description:** A medium mangrove with small flowers, narrow propagules, and pointed leaves.

**Key identification characteristics:** Leaves are opposite, elliptic, pointed, and often show tiny dark dots beneath. Knee roots and a flanged trunk base may be visible. Bark is gray and fissured. Small greenish-white to yellow-green flowers occur in clusters of several flowers and usually have eight calyx lobes. Propagules are smooth, slender, slightly curved, and commonly about 9-14 cm long.

**Ecological information:** It adds mid-canopy and root complexity to riverine mangrove forest and contributes litter to estuarine food webs. It ranges across South and Southeast Asia to the western Pacific, including Philippine mangrove swamps. It is often found in downstream to intermediate, middle-intertidal mud. Global status: Least Concern.

**Educational information:** Roxburgh published the basionym in 1824, and the accepted combination appeared in 1836. The epithet means "small-flowered," a helpful field reminder.

**Reason for addition:** It expands *Bruguiera* biodiversity and teaches students to use flower clusters, lower-leaf dots, and propagule shape rather than relying on roots alone. Illustrated records are available, although confusion with *B. cylindrica* reduces immediately usable material; CNN candidate availability is **Medium-High**.

**References:** [SEAFDEC-2004], [CDFP-Rhizophoraceae], [FAO-2007].

### 7. *Bruguiera sexangula*

**Scientific name:** *Bruguiera sexangula* (Lour.) Poir.  
**Common name:** Upriver orange mangrove; pototan  
**Family:** Rhizophoraceae  
**Description:** A large *Bruguiera* adapted to upstream and less frequently flooded mangrove habitat.

**Key identification characteristics:** Leaves are opposite, large, leathery, and elliptic. The root system may include knee roots, flanged buttresses, and occasional low stilt roots. Bark is gray-brown, lenticellate, and smooth to fissured. Flowers are usually solitary and pendulous, with a large calyx commonly divided into 10-14 lobes. Propagules are short, thick, and characteristically six-angled in cross-section.

**Ecological information:** It stabilizes upper tidal banks and contributes tall-canopy habitat in lower-salinity reaches. It occurs from South Asia through Southeast Asia, including many Philippine islands. Zonation is upper/interior mangrove and tidal waterways that are flooded less often. Global status: Least Concern.

**Educational information:** Loureiro described the basionym in 1790; Poiret published the accepted combination in 1816. The name `sexangula` refers to the propagule's six angles.

**Reason for addition:** It is both ecologically and visually distinct from the existing *B. gymnorrhiza* class, yet the two are commonly confused. It supports upriver-zonation education and comparative propagule study. Public image availability is **High**.

**References:** [SEAFDEC-2004], [CDFP-Rhizophoraceae], [FAO-2007].

### 8. *Camptostemon philippinensis*

**Scientific name:** *Camptostemon philippinensis* (S.Vidal) Becc.  
**Common name:** Gapas-gapas  
**Family:** Malvaceae  
**Description:** A rare, soft-wooded mangrove endemic to the Philippines and Sulawesi, usually found at mangrove edges and tidal creeks.

**Key identification characteristics:** Leaves are obovate to elliptic-lanceolate, crowded near twig ends, and retain fine scales on both surfaces. Surface roots can form knobby pneumatophores around a gnarled trunk base. Bark is gray to brown, longitudinally fissured, and lenticellate. Tiny white, five-petaled flowers occur in crowded axillary clusters and have five stamens. Capsule-like fruits release small seeds covered in conspicuous white cottony hairs.

**Ecological information:** It contributes rare-species diversity and structure along tidal creeks and inner mangrove edges. Its natural range is limited to the Philippines and Sulawesi. Field sources place it at mangrove margins and low-intertidal tidal creeks. Global status: Endangered; it is also listed as Endangered under DENR DAO 2017-11.

**Educational information:** Vidal described the basionym *Cumingia philippinensis* in 1885, and Beccari published the accepted combination in 1889. The local name refers to the cotton-like seed hairs. A modern taxonomic revision confirms leaf-scale and five-stamen characters.

**Reason for addition:** This is one of the strongest conservation and Philippine-endemism additions SILVAMANG can make. It is valuable for conservation monitoring, restoration research, and teaching rare-species recognition. Candidate material exists in SEAFDEC, Kew, Smithsonian Open Access, and herbarium collections, but wild photographs are limited; CNN availability is **Low-Medium** and requires partnerships with experts and protected sites.

**References:** [FAO-Camptostemon], [WFO-Camptostemon], [Camptostemon-revision], [DENR-Camptostemon].

### 9. *Ceriops zippeliana*

**Scientific name:** *Ceriops zippeliana* Blume  
**Common name:** Ceriops; malatangal (older Philippine material often reported as *C. decandra*)  
**Family:** Rhizophoraceae  
**Description:** A relatively rare Southeast Asian *Ceriops* now recognized as distinct from the South Asian *C. decandra*.

**Key identification characteristics:** Leaves are opposite and oval to elliptical-oval. Knee roots and a low buttressed base may develop in firm mud. Bark is gray-brown and smooth to lightly fissured. Flowers form a simple, compact, head-like inflorescence with a single layer of bracts. Fruits have a shallow disc-like calyx with short erect lobes; the thick propagule is uneven in width and narrows to an acute tip.

**Ecological information:** It contributes understory structure and sediment stability at mangrove edges. Its confirmed range extends from the Malay Peninsula through Borneo, Java, the Philippines, Sulawesi, and nearby islands. In the Philippines it occurs from Luzon to Mindanao but is much less common than *C. tagal*. It generally occupies middle to upper intertidal edges and firm mud. Global status: Least Concern, but Philippine populations are locally rare.

**Educational information:** Blume described the species in the nineteenth century. It was long merged with *C. decandra* until a 2009 morphological and molecular study demonstrated their separation. That study is a strong example of why a modern database must preserve aliases and taxonomic evidence.

**Reason for addition:** It prevents Philippine observations from being assigned to either the current *C. tagal* class or the geographically inappropriate *C. decandra* name. It is highly useful for taxonomy education and biodiversity surveys. CDFP has some Philippine photographs, but public observations are sparse and commonly mislabeled; CNN availability is **Low**.

**References:** [CDFP-Rhizophoraceae], [Ceriops-study], [Sarangani-study].

### 10. *Heritiera littoralis*

**Scientific name:** *Heritiera littoralis* Dryand. ex Aiton  
**Common name:** Looking-glass mangrove; dungon-late  
**Family:** Malvaceae (Sterculioideae; older works use Sterculiaceae)  
**Description:** A large coastal and back-mangrove tree recognized by silvery leaf undersides and strongly keeled fruits.

**Key identification characteristics:** Leaves are alternate, leathery, elliptic to obovate, green above, and densely silver or coppery-scaled beneath. Strong plank buttresses support mature trunks; pneumatophores are generally absent. Bark is pale gray to pinkish-gray and becomes fissured or flaky. Small unisexual reddish-purple or brownish bell-shaped flowers occur in branched clusters. The fruit is hard, woody, one-seeded, and has a conspicuous raised keel that aids flotation.

**Ecological information:** It links mangrove and coastal forest, provides tall-canopy habitat, and stabilizes landward margins. It is widespread around the Indo-Pacific and is a common constituent of Philippine coastal forests and mangroves. It favors back mangrove, tidal riverbanks, and sandy or rocky landward margins with less frequent inundation. Global status: Least Concern.

**Educational information:** The name was published in 1789. The pale leaf underside can flash like a mirror in wind, explaining the common name. The keeled fruit is an excellent example of water-dispersal morphology.

**Reason for addition:** It extends the guide beyond prop-root trees and helps students recognize the mangrove-to-beach-forest transition. It is useful in canopy, seed-dispersal, and zonation studies. It is widely photographed in CDFP and biodiversity portals; CNN availability is **High**.

**References:** [SEAFDEC-2004], [CDFP-Sterculiaceae], [FAO-2007].

### 11. *Kandelia candel*

**Scientific name:** *Kandelia candel* (L.) Druce  
**Common name:** Kandelia; Baler bakauan; tangal  
**Family:** Rhizophoraceae  
**Description:** A viviparous true mangrove with a highly restricted Philippine population known from Aurora Province.

**Key identification characteristics:** Leaves are opposite, elliptic-oblong, and have slightly inrolled margins. Roots may form low buttresses or braided surface roots but usually lack conspicuous pneumatophores. Bark is smooth gray to reddish-brown with lenticels. Branched clusters carry several white flowers with five or six narrow calyx lobes that curve backward. The small ovoid fruit bears a long, club-shaped viviparous propagule, commonly 15-40 cm long.

**Ecological information:** It stabilizes muddy tidal banks and adds rare genetic and species diversity. The species ranges from South and Southeast Asia northward to southern China; the only confirmed Philippine natural population is in Aurora. It occurs along muddy tidal creeks and rivers, usually in the back mangrove, with *Nypa* and *Sonneratia*. Global status: Least Concern; Philippine DENR category: Critically Endangered.

**Educational information:** The basionym dates to Linnaeus in 1753 and Druce published the accepted combination in 1914. Philippine plants were first identified in Aurora in 1996. A 2021 Philippine Journal of Science population and taxonomic study strongly supported their native status after years of debate about possible introduction.

**Reason for addition:** It is a top conservation-monitoring priority and teaches how global and national threat categories can differ. Its flowers and long propagules are highly informative for identification. Official guide and research images exist, but local populations must not be disturbed and public volume is limited; CNN availability is **Low-Medium** and should rely on permitted, non-destructive imaging.

**References:** [Kandelia-PJS], [CDFP-Rhizophoraceae], [NParks-Kandelia], [DENR-DAO].

### 12. *Lumnitzera littorea*

**Scientific name:** *Lumnitzera littorea* (Jack) Voigt  
**Common name:** Red-flowered black mangrove; tabao  
**Family:** Combretaceae  
**Description:** A back-mangrove tree whose bright red flowers make it one of the easiest *Lumnitzera* species to recognize.

**Key identification characteristics:** Leaves are alternate or spirally arranged, fleshy, obovate, and rounded or shallowly notched at the tip. Short pneumatophores may occur around mature trees. Bark is dark brown and deeply fissured. Flowers are conspicuous, bright red, usually five-petaled, and borne in axillary clusters. Fruits are small, one-seeded, vase-shaped to ellipsoid, ribbed, fibrous, and water-dispersed.

**Ecological information:** It supports pollinators and stabilizes elevated mangrove margins. It occurs through the Indo-Pacific and throughout Philippine seashores and tidal streams. It is most associated with middle to high intertidal and back-mangrove sandy or muddy ground. Global status: Least Concern.

**Educational information:** Jack described the basionym in 1822 and Voigt published the accepted combination in 1845. Its red flowers make a memorable comparison with the white-flowered *L. racemosa*.

**Reason for addition:** It supplies a clear flower-based field class and improves high-zone biodiversity coverage. It is useful in pollination, phenology, and restoration-site lessons. Distinctive flowers and illustrated Philippine records support **Medium-High** CNN candidate availability.

**References:** [SEAFDEC-2004], [CDFP-Combretaceae], [FAO-2007].

### 13. *Lumnitzera racemosa*

**Scientific name:** *Lumnitzera racemosa* Willd.  
**Common name:** White-flowered black mangrove; kulasi; tabao  
**Family:** Combretaceae  
**Description:** A common high-shore mangrove tree with small white flowers and compact fleshy leaves.

**Key identification characteristics:** Leaves are alternate or spiral, almost stalkless, narrow-obovate, fleshy, and rounded or notched. Surface roots occur, but conspicuous aerial roots may be absent. Bark is dark gray-brown, rough, and fissured. Small fragrant white flowers occur in axillary spikes or short racemes. Fruits are small, ellipsoid, one-seeded, longitudinally ridged, and darken at maturity.

**Ecological information:** It stabilizes firm upper-shore soil and supplies flowers, litter, and woody habitat at the landward mangrove edge. It is widespread from Africa and South Asia across Southeast Asia and the Pacific, including the Philippines. It favors high intertidal, back-mangrove, firm mud, sand, and sometimes rocky coasts. Global status: Least Concern.

**Educational information:** Willdenow published the name in 1803. The red-versus-white flower comparison between the two *Lumnitzera* species is one of the simplest reliable field lessons in the guide.

**Reason for addition:** It is ecologically common enough to be encountered by users and visually important for differentiating the genus. It supports high-intertidal and phenology research. Public photographs are broadly available; CNN availability is **High**.

**References:** [SEAFDEC-2004], [CDFP-Combretaceae], [FAO-2007].

### 14. *Nypa fruticans*

**Scientific name:** *Nypa fruticans* Wurmb  
**Common name:** Nipa palm; nipa; sasa  
**Family:** Arecaceae  
**Description:** A distinctive trunkless mangrove palm that forms extensive stands along brackish tidal rivers.

**Key identification characteristics:** Large pinnate fronds arise directly from an underground horizontal stem; individual leaflets are long and lanceolate. Dense fibrous roots anchor the buried rhizome, and there is no normal above-ground barked trunk. Female flowers form a spherical head, while male flowers occur on catkin-like side branches. Many woody, wedge-shaped fruits form a large brown ball; mature units separate and float.

**Ecological information:** Nipa stands stabilize soft banks, trap sediment, store carbon, and provide habitat and important traditional materials. It is widespread from South and Southeast Asia to the western Pacific and is common in the Philippines. It dominates upper estuaries, tidal rivers, and soft low-salinity mud in the landward mangrove zone. Global status: Least Concern.

**Educational information:** Wurmb described the species in the eighteenth century. Fossil evidence shows that relatives of *Nypa* once had a much wider ancient distribution. The plant is also culturally important for roofing, weaving, sap, sugar, vinegar, and other products when harvested sustainably.

**Reason for addition:** It adds the only mangrove palm and is essential to any Philippine educational database. It supports ethnobotany, river-zonation, and carbon research. Images are abundant and visually distinct, giving **High** candidate availability, although the current tree-focused plant-part pipeline will need palm-aware labels.

**References:** [SEAFDEC-2004], [CDFP-Arecaceae], [FAO-2007].

### 15. *Osbornia octodonta*

**Scientific name:** *Osbornia octodonta* F.Muell.  
**Common name:** Myrtle mangrove; bunot-bunot; tawalis  
**Family:** Myrtaceae  
**Description:** A salt-tolerant shrub or small tree of exposed high-shore rocky and sandy habitat.

**Key identification characteristics:** Leaves are small, opposite, brittle, aromatic when crushed, and marked with oil glands. Cable-like surface roots may be exposed over rock or sand. Bark is thick, spongy, brown to gray, and deeply longitudinally fissured. Flowers are small and white. Fruits are small dry capsules rather than fleshy berries or long propagules.

**Ecological information:** It occupies a harsh high-salinity niche, stabilizes exposed shore margins, and contributes habitat where taller muddy-forest mangroves may not persist. It occurs from northern Australia through parts of Malesia, including the Philippines. Zonation is middle to high intertidal on rocky, coral-derived, or sandy ground, often with *Pemphis* and *Aegiceras floridum*. Global status: Least Concern.

**Educational information:** Ferdinand von Mueller published the species in 1862. It is the only species in its genus, and its aromatic leaves help separate it from superficially similar *Aegiceras floridum*.

**Reason for addition:** It improves coverage of exposed-shore mangroves and teaches that mangrove habitat is not always soft mud. It is useful for salinity and substrate research. Philippine guide photographs and occurrence images exist, but volume is moderate; CNN availability is **Medium**.

**References:** [SEAFDEC-2004], [CDFP-Myrtaceae], [FAO-2007].

### 16. *Pemphis acidula*

**Scientific name:** *Pemphis acidula* J.R.Forst. & G.Forst.  
**Common name:** Bantigi; ironwood mangrove  
**Family:** Lythraceae  
**Description:** A slow-growing, hard-wooded shrub or small tree of coral rock, limestone, and exposed high-tide shores.

**Key identification characteristics:** Leaves are small, opposite, thick, gray-green, and narrowly elliptic to oblong. Roots spread through rock crevices and surface substrate but do not form conspicuous pneumatophores. Bark is rough gray-brown with large lenticels. Flowers are small, usually solitary and white, with six crinkled petals. Fruits are small urn- or cup-shaped capsules retained within a persistent calyx.

**Ecological information:** It holds exposed coral and rocky margins, tolerates salt spray, and adds habitat at the upper limit of mangroves. It is widespread in tropical Indo-Pacific coasts and occurs throughout the Philippines. Zonation is high intertidal and the upper shore on coral, rock, or sand. Global status: Least Concern; Philippine DENR category: Endangered.

**Educational information:** The Forsters published the name in 1776. Its exceptionally dense wood and compact form made it sought after for construction and bonsai, and Philippine field literature records confiscation of illegally collected specimens. That history is useful for conservation education.

**Reason for addition:** It adds an important high-shore and nationally threatened species. It helps users avoid treating rocky-coast vegetation as unrelated to mangroves. Wild and cultivated images are available, giving **Medium-High** candidate availability, but training data must exclude or separately tag heavily shaped bonsai specimens.

**References:** [SEAFDEC-2004], [CDFP-Lythraceae], [POWO-Pemphis], [DENR-DAO].

### 17. *Scyphiphora hydrophylacea*

**Scientific name:** *Scyphiphora hydrophylacea* C.F.Gaertn.  
**Common name:** Nilad  
**Family:** Rubiaceae  
**Description:** A shrub or small mangrove tree with glossy leaves, pinkish flowers, and distinctly grooved fruits.

**Key identification characteristics:** Leaves are opposite, glossy, leathery, obovate to elliptic, and rounded at the tip. Surface roots and occasional small stilt roots may occur. Bark is brownish gray. Small pale-pink to whitish, fragrant flowers occur in dense axillary clusters. Fruits are fleshy and ellipsoid, changing from green to yellow and glossy brown, with six to ten strong longitudinal grooves.

**Ecological information:** It stabilizes inner shorelines and supplies flowers and fruit for coastal fauna. It ranges from the western Indian Ocean through Southeast Asia to the western Pacific and is native across many Philippine islands. It favors middle to high intertidal, backshore, and firm or sandy mud along saline and brackish tidal streams. Global status: Least Concern.

**Educational information:** Gaertner published the name in 1805. Current taxonomy places the historical Philippine names *Ixora manilana* and *Psychotria philippensis* in synonymy with this species. Philippine tradition often links the name nilad with Maynilad/Manila; present this as a historical tradition rather than a settled linguistic fact.

**Reason for addition:** Nilad has high Philippine cultural and botanical value and its grooved fruit is an excellent identification character. It supports lessons on taxonomy, pollination, and cultural history. CDFP and NParks provide illustrated records, producing **Medium-High** candidate availability.

**References:** [SEAFDEC-2004], [CDFP-Rubiaceae], [NParks-Scyphiphora], [POWO-Scyphiphora].

### 18. *Sonneratia caseolaris*

**Scientific name:** *Sonneratia caseolaris* (L.) Engl.  
**Common name:** Mangrove apple; pagatpat; pedada  
**Family:** Lythraceae  
**Description:** A tall, fast-growing riverine mangrove with large breathing roots, night-opening flowers, and edible fruits.

**Key identification characteristics:** Leaves are opposite, leathery, broadly elliptic to oval, and rounded. Conical pneumatophores can be tall and numerous. Bark is gray-brown and slightly fissured. Large flowers open around dusk, have narrow reddish petals and masses of white to pink stamens, and are visited by nocturnal animals. Fruits are large, round to flattened green berries resting in a persistent star-shaped calyx.

**Ecological information:** It stabilizes upper tidal rivers, provides food and roost structure, and supports estuarine fauna. It is widespread from South Asia through Southeast Asia and the western Pacific, including the Philippines. It favors deep soft mud, brackish backwaters, tidal creeks, and low-salinity upstream zones. Global status: Least Concern.

**Educational information:** Linnaeus published the basionym in 1754; Engler published the accepted combination in 1897. Its flowers are short-lived and open at night, making it useful for teaching bat and moth pollination. Some Southeast Asian populations are associated with synchronous firefly displays.

**Reason for addition:** It completes a major missing *Sonneratia* comparison with existing *S. alba* and will reduce likely misidentification. It supports river-zonation, pollination, and food-web studies. Public photographs are abundant; CNN availability is **High**.

**References:** [SEAFDEC-2004], [CDFP-Lythraceae], [FAO-2007].

### 19. *Sonneratia ovata*

**Scientific name:** *Sonneratia ovata* Backer  
**Common name:** Mangrove apple; pedada  
**Family:** Lythraceae  
**Description:** A relatively rare back-mangrove *Sonneratia* with very broad leaves and flowers that generally lack petals.

**Key identification characteristics:** Leaves are opposite, broad-ovate to nearly circular, thick, and rounded. Short conical pneumatophores are common. Bark is rough and brown. Flowers open around dusk, have red-tinged sepals, many pale stamens, and usually no petals. Fruits are pear-shaped to rounded green berries with a persistent calyx.

**Ecological information:** It adds rare-species diversity to upper estuarine forest and can indicate low-salinity, landward habitat. It occurs in Southeast Asia and the western Pacific; current Philippine records include Leyte, Batangas, and Polillo. It favors high intertidal, back-mangrove, muddy, fresh-to-brackish sites and is locally uncommon. Global status: Near Threatened.

**Educational information:** Backer published the species in 1920. Its petal-free flowers and nearly round leaves provide a strong three-way comparison with *S. alba* and *S. caseolaris*.

**Reason for addition:** It is a conservation-relevant Philippine species and prevents rare observations from being absorbed into the existing *S. alba* class. It supports zonation and threatened-species education. Official and biodiversity images exist, but rarity constrains balanced collection; CNN availability is **Medium**.

**References:** [SEAFDEC-2004], [CDFP-Lythraceae], [FAO-2007].

### 20. *Xylocarpus rumphii*

**Scientific name:** *Xylocarpus rumphii* (Kostel.) Mabb.  
**Common name:** Puzzle-nut tree; nyireh; older Philippine guides may use piagao  
**Family:** Meliaceae  
**Description:** A coastal *Xylocarpus* of exposed rocky or sandy shores, distinct from the current muddy-mangrove *X. granatum* record.

**Key identification characteristics:** Leaves are opposite and compound, with two to four pairs of leathery ovate to heart-shaped leaflets with pointed tips. Conspicuous buttresses and pneumatophores are generally absent. Bark is finely fissured and gray, with pink to red inner bark. Creamy-white, four-petaled flowers occur in long, loose, hanging clusters. Fruits are round and woody, about 6-8 cm across, and contain several irregular interlocking seeds.

**Ecological information:** It stabilizes exposed coastal margins and provides woody habitat and host-plant resources. It ranges from East Africa through Malesia to Australia and the Pacific, with Philippine records from multiple islands. It favors rocky cliffs, exposed shores, and sand above or near the high-water line rather than deep tidal mud. Global status: Least Concern.

**Educational information:** The accepted combination was published by Mabberley in 1982 from a nineteenth-century basionym. The name honors Georg Eberhard Rumphius, an important early naturalist of Malesian plants. Current Philippine flora treats older Philippine reports of *X. moluccensis* as a misapplied name for *X. rumphii*.

**Reason for addition:** It gives students a necessary comparison with the existing *X. granatum* class and teaches coastal-substrate specialization. It is useful for taxonomy and beach-to-mangrove transition studies. CDFP and NParks have photographs, but old-name confusion requires strict expert review; CNN availability is **Medium**.

**References:** [CDFP-Meliaceae], [NParks-Xylocarpus-rumphii], [FAO-2007].

## Duplicate and Alias Decisions

| Proposed/legacy name encountered | Decision | Reason |
| --- | --- | --- |
| *Avicennia rumphiana* | Do not add | Same taxon already stored as *A. marina* var. *rumphiana* |
| *Camptostemon philippinense* | Alias only | Kew/WFO accepted spelling is *C. philippinensis* |
| *Ceriops decandra* for Philippine material | Do not add in this batch | Current Philippine treatment identifies this material as *C. zippeliana*; true *C. decandra* is centered farther west |
| *Xylocarpus moluccensis* for Philippine material | Do not add in this batch | Current Philippine flora treats the old Philippine usage as misapplied and recognizes *X. rumphii* |
| *Rhizophora x lamarckii* | Defer | Hybrid class requires parent-aware labels and enough verified examples |
| *Sonneratia x gulngai* | Defer | Hybrid class requires parent-aware labels and enough verified examples |

## Deliberately Deferred Scope

The Philippine mangrove flora is broader than this first expansion. *Acanthus* shrubs, *Acrostichum* ferns, and a number of beach-forest/mangrove-associated plants were not recommended in this batch. The existing project guide already excludes *Acanthus* from the current 10-class model, and fern/shrub growth forms need adjusted plant-part labels, sampling rules, and negative-class design. They can form a later, separately approved expansion instead of being mixed into the tree classifier without preparation.

## CNN Expansion Safety Plan

1. Do not edit any active `class_order.json` or `species_labels.txt` file when adding database profiles.
2. Add a database field or API flag such as `identification_support = knowledge_only` so the app never claims the current CNN recognizes a newly added species.
3. Create candidate folders and manifest rows separately from the active 10-class training set.
4. Set a minimum target per candidate species and per plant part before training. A practical starting target is at least 300 expert-verified, deduplicated images per species, with no single source or location dominating.
5. Record source URL, creator, license, permission, place, date, plant part, reviewer, quality, and split for every image.
6. Use perceptual-hash and sequence checks to prevent near-duplicate train/test leakage.
7. Include confusing species pairs in the evaluation plan: all four *Avicennia*, all *Bruguiera*, both *Ceriops*, all *Sonneratia*, both *Lumnitzera*, and both *Xylocarpus*.
8. Train and validate a new model, freeze its exact class order, then update the service and mobile class-order files together with the model artifact.
9. Report per-class precision, recall, F1, confusion matrix, top-k accuracy, calibration, and field-site holdout performance. Overall accuracy alone is not enough.
10. Obtain expert botanical sign-off before promoting any new class to production.

## Proposed Implementation After Approval

No step below has been executed yet.

1. Add the approved species through an idempotent, additive seeder that checks normalized scientific names and aliases before insert.
2. Add complete `mangrove_education` records for each approved species, including the identification, ecology, history, conservation, and source data in this report.
3. Add matching Flutter offline education entries so result and species pages remain useful without internet access.
4. Add species-specific knowledge-base questions and answers for identification comparisons, zonation, conservation, and common-name aliases.
5. Expose an explicit `knowledge_only` or `cnn_supported` status in API/mobile models and species screens.
6. Keep all new species out of active predictions until retraining is complete.
7. Do not create map distribution pins from general range descriptions. Add only voucher-backed, survey-backed, or otherwise verified coordinates, with source and observation date.
8. Add automated tests for uniqueness, education coverage, alias lookup, API output, offline fallback, and the invariant that model output count equals class-order length.
9. Separately correct existing conservation fields only if that correction is included in the approval.

## Approval Choices

The safest approval is:

> Approve all 20 species for database, knowledge-base, and educational-guide support only. Keep the active CNN at 10 classes until retraining. Also approve correction of the two existing conservation statuses, but do not rename existing species or CNN labels.

Alternatively, approval may list a smaller subset or exclude the two existing status corrections.

## References

[SEAFDEC-2004]: https://repository.seafdec.org.ph/handle/10862/3053 "Primavera et al. (2004), Handbook of Mangroves in the Philippines - Panay"
[SEAFDEC-2009]: https://repository.seafdec.org.ph/handle/10862/6063 "Primavera (2009), Field Guide to Philippine Mangroves"
[FAO-2007]: https://www.fao.org/4/ag132e/ag132e00.pdf "FAO, Mangrove Guidebook for Southeast Asia"
[CDFP-home]: https://www.philippineplants.org/ "Co's Digital Flora of the Philippines"
[CDFP-Primulaceae]: https://www.philippineplants.org/Families/Primulaceae.html
[CDFP-Acanthaceae]: https://www.philippineplants.org/Families/Acanthaceae.html
[CDFP-Rhizophoraceae]: https://www.philippineplants.org/Families/Rhizophoraceae.html
[CDFP-Sterculiaceae]: https://www.philippineplants.org/Families/Sterculiaceae.html
[CDFP-Combretaceae]: https://www.philippineplants.org/Families/Combretaceae.html
[CDFP-Arecaceae]: https://www.philippineplants.org/Families/Arecaceae.html
[CDFP-Myrtaceae]: https://www.philippineplants.org/Families/Myrtaceae.html
[CDFP-Lythraceae]: https://www.philippineplants.org/Families/Lythraceae.html
[CDFP-Rubiaceae]: https://www.philippineplants.org/Families/Rubiaceae.html
[CDFP-Meliaceae]: https://www.philippineplants.org/Families/Meliaceae.html
[POWO-Aegiceras-floridum]: https://powo.science.kew.org/taxon/urn%3Alsid%3Aipni.org%3Anames%3A586620-1/general-information
[POWO-Pemphis]: https://powo.science.kew.org/taxon/urn%3Alsid%3Aipni.org%3Anames%3A554064-1
[POWO-Scyphiphora]: https://powo.science.kew.org/taxon/urn%3Alsid%3Aipni.org%3Anames%3A73566-3
[WFO-Camptostemon]: https://www.worldfloraonline.org/taxon/wfo-0000583114
[FAO-Camptostemon]: https://www.fao.org/4/ag132e/ag132e08.pdf
[Camptostemon-revision]: https://www.vliz.be/imisdocs/publications/391947.pdf
[DENR-Camptostemon]: https://erdbservices.denr.gov.ph/eskris/iec_for_guest.php?operation=view&pk0=584
[Ceriops-study]: https://repository.naturalis.nl/pub/524746
[Sarangani-study]: https://pmc.ncbi.nlm.nih.gov/articles/PMC10848689/
[Kandelia-PJS]: https://philjournalsci.dost.gov.ph/kandelia-candel-l-druce-a-true-native-species-in-the-philippines/
[NParks-Kandelia]: https://www.nparks.gov.sg/florafaunaweb/flora/6/5/6540
[NParks-Scyphiphora]: https://www.nparks.gov.sg/florafaunaweb/flora/2/4/2444
[NParks-Xylocarpus-rumphii]: https://www.nparks.gov.sg/florafaunaweb/flora/3/2/3210
[DENR-DAO]: https://www.philippineplants.org/Resources/dao-2017-11.pdf "DENR Administrative Order 2017-11"
