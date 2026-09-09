<?php

namespace Database\Seeders;

use App\Models\MangroveEducation;
use App\Models\Species;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;

class MangroveEducationSeeder extends Seeder
{
    public function run(): void
    {
        if (! Schema::hasTable('mangrove_education')) {
            return;
        }

        foreach ($this->entries() as $scientificName => $entry) {
            $species = Species::where('scientific_name', $scientificName)->first();

            if (! $species) {
                continue;
            }

            MangroveEducation::updateOrCreate(
                ['species_id' => $species->id],
                $entry + ['status' => 'active']
            );
        }
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    private function entries(): array
    {
        $sharedEcology = [
            'Protects coasts by slowing waves and trapping sediment.',
            'Helps reduce erosion along muddy shorelines and estuaries.',
            'Creates nursery habitat for fish, crabs, shrimp, and other marine life.',
            'Stores blue carbon in wood, roots, and waterlogged soil.',
            'Supports biodiversity and climate-change adaptation in coastal communities.',
        ];

        $sharedHistory = 'Mangroves were known and used by coastal communities for centuries before formal scientific study. People recognized their value for fishing grounds, shoreline shelter, fuelwood, medicines, and navigation. Conservation efforts later grew as researchers documented mangrove loss, coastal protection benefits, nursery habitat value, and blue-carbon storage.';
        $sharedStudy = 'Mangroves were not discovered by one person. Early communities already knew these forests, while later botanists and ecologists documented their taxonomy, salt tolerance, root adaptations, distribution, and ecosystem services. Modern study combines field identification, herbarium records, ecological monitoring, remote sensing, and community-based biodiversity surveys.';
        $sharedConservation = [
            'Avoid cutting or clearing mangroves without ecological assessment and permits.',
            'Prevent plastic waste, wastewater, and chemical pollution from entering mangrove areas.',
            'Maintain tidal flow so roots and seedlings receive natural brackish water exchange.',
            'Use native species and monitor survival when doing restoration.',
            'Record GPS, photos, species, and measurements to support biodiversity monitoring.',
        ];
        $references = [
            'Tomlinson, P. B. The Botany of Mangroves.',
            'Spalding, Kainuma, and Collins. World Atlas of Mangroves.',
            'FAO mangrove conservation and restoration guidance.',
            'Alongi, D. M. Mangrove forests: resilience, protection, and ecosystem services.',
        ];

        return [
            'Rhizophora apiculata' => [
                'overview' => 'Rhizophora apiculata is a true mangrove commonly recognized by its strong stilt roots and opposite glossy leaves. It often grows in muddy intertidal areas and helps stabilize sheltered shorelines.',
                'physical_characteristics' => ['Stilt-rooted tree with dense branching.', 'Glossy opposite leaves with a pointed tip.', 'Viviparous propagules adapted for tidal dispersal.'],
                'leaf_characteristics' => 'Leaves are opposite, leathery, glossy green, and usually pointed at the tip.',
                'root_characteristics' => 'Prominent stilt roots support the trunk in soft mud and help resist waves and currents.',
                'habitat' => ['Muddy shorelines', 'Estuaries', 'Tidal creeks', 'Sheltered coastal forests'],
                'distribution' => ['Philippines', 'Southeast Asia', 'Indonesia', 'Malaysia', 'Western Pacific coasts'],
                'ecological_importance' => $sharedEcology,
                'history' => $sharedHistory,
                'scientific_study' => $sharedStudy,
                'conservation_information' => $sharedConservation,
                'interesting_facts' => ['Stilt roots can trap sediment and help build stable shoreline zones.', 'Propagules can float before rooting in suitable mud.', 'Root systems provide shelter for juvenile fish and crabs.'],
                'references' => $references,
            ],
            'Rhizophora mucronata' => [
                'overview' => 'Rhizophora mucronata is a stilt-rooted mangrove often found along tidal waterways and muddy shores. It is important in forming protective mangrove stands.',
                'physical_characteristics' => ['Tall stilt-rooted mangrove tree.', 'Large leaves with a noticeable mucronate tip.', 'Long propagules that can disperse with tides.'],
                'leaf_characteristics' => 'Leaves are opposite, broad, leathery, and often have a small pointed tip.',
                'root_characteristics' => 'Stilt and prop roots anchor the plant in soft, waterlogged sediment.',
                'habitat' => ['Tidal creeks', 'River mouths', 'Muddy shorelines', 'Sheltered intertidal forests'],
                'distribution' => ['Philippines', 'Southeast Asia', 'Indian Ocean coasts', 'Western Pacific coasts'],
                'ecological_importance' => $sharedEcology,
                'history' => $sharedHistory,
                'scientific_study' => $sharedStudy,
                'conservation_information' => $sharedConservation,
                'interesting_facts' => ['Long propagules help the species spread through tidal water.', 'Stilt roots add complex habitat for marine organisms.', 'Often used in restoration where hydrology suits Rhizophora species.'],
                'references' => $references,
            ],
            'Rhizophora stylosa' => [
                'overview' => 'Rhizophora stylosa is a coastal fringe mangrove with stilt roots. It is commonly associated with sheltered shores, reef flats, and sandy-muddy substrates.',
                'physical_characteristics' => ['Stilt-rooted mangrove tree or shrub.', 'Leathery opposite leaves.', 'Propagules adapted to tidal movement.'],
                'leaf_characteristics' => 'Leaves are opposite and leathery, helping reduce water loss in salty coastal conditions.',
                'root_characteristics' => 'Stilt roots provide support and help the plant withstand tidal movement.',
                'habitat' => ['Coastal fringes', 'Sheltered shores', 'Sandy-muddy coasts', 'Reef-associated mangrove areas'],
                'distribution' => ['Philippines', 'Southeast Asia', 'Northern Australia', 'Western Pacific islands'],
                'ecological_importance' => $sharedEcology,
                'history' => $sharedHistory,
                'scientific_study' => $sharedStudy,
                'conservation_information' => $sharedConservation,
                'interesting_facts' => ['Can grow closer to open coastal water than some inner-zone mangroves.', 'Stilt roots improve shoreline complexity.', 'Often part of mixed Rhizophora stands.'],
                'references' => $references,
            ],
            'Avicennia marina' => [
                'overview' => 'Avicennia marina, commonly called grey mangrove, is a hardy mangrove known for pencil-like breathing roots called pneumatophores. It tolerates salty and exposed coastal conditions.',
                'physical_characteristics' => ['Hardy mangrove tree or shrub.', 'Greyish bark and salt-tolerant leaves.', 'Pencil-like pneumatophores around the trunk.'],
                'leaf_characteristics' => 'Leaves are usually opposite, thick, and may appear greyish underneath because of salt-management adaptations.',
                'root_characteristics' => 'Pneumatophores rise from the soil to help gas exchange in waterlogged mud.',
                'habitat' => ['Tidal flats', 'Muddy shorelines', 'Estuaries', 'Open coastal margins'],
                'distribution' => ['Philippines', 'Southeast Asia', 'Indian Ocean coasts', 'Pacific coasts'],
                'ecological_importance' => $sharedEcology,
                'history' => $sharedHistory,
                'scientific_study' => $sharedStudy,
                'conservation_information' => $sharedConservation,
                'interesting_facts' => ['Pneumatophores act like breathing structures above the mud.', 'This species can tolerate high salinity.', 'Leaves can help manage excess salt.'],
                'references' => $references,
            ],
            'Avicennia marina var. rumphiana' => [
                'overview' => 'Avicennia marina var. rumphiana is a variety associated with intertidal mangrove habitats. It shares the salt tolerance and breathing-root adaptations of Avicennia mangroves.',
                'physical_characteristics' => ['Mangrove tree or shrub with grey mangrove traits.', 'Salt-tolerant leaves.', 'Pneumatophores in suitable muddy substrates.'],
                'leaf_characteristics' => 'Leaves are thick and adapted to salty coastal environments.',
                'root_characteristics' => 'Breathing roots help oxygen exchange where sediment is waterlogged.',
                'habitat' => ['Coastal intertidal zones', 'Sheltered muddy shores', 'Brackish mangrove margins'],
                'distribution' => ['Philippines', 'Southeast Asia', 'Malesian region'],
                'ecological_importance' => $sharedEcology,
                'history' => $sharedHistory,
                'scientific_study' => $sharedStudy,
                'conservation_information' => $sharedConservation,
                'interesting_facts' => ['Often identified using a combination of roots, leaves, flowers, and local taxonomy.', 'Can occur with other Avicennia and Rhizophora species.', 'Supports sediment trapping in intertidal zones.'],
                'references' => $references,
            ],
            'Sonneratia alba' => [
                'overview' => 'Sonneratia alba is a true mangrove often found near seaward edges and tidal channels. It is known for breathing roots and coastal fringe habitat.',
                'physical_characteristics' => ['Mangrove tree with rounded canopy.', 'Often grows near open tidal water.', 'Produces pneumatophores in waterlogged sediment.'],
                'leaf_characteristics' => 'Leaves are simple, opposite, and adapted to salty coastal exposure.',
                'root_characteristics' => 'Cone-like pneumatophores help roots obtain oxygen in flooded mud.',
                'habitat' => ['Seaward mangrove edges', 'Tidal channels', 'Sandy-muddy shores', 'Open estuarine margins'],
                'distribution' => ['Philippines', 'Southeast Asia', 'Indian Ocean coasts', 'Western Pacific coasts'],
                'ecological_importance' => $sharedEcology,
                'history' => $sharedHistory,
                'scientific_study' => $sharedStudy,
                'conservation_information' => $sharedConservation,
                'interesting_facts' => ['Often grows on the seaward side of mangrove forests.', 'Breathing roots can be visible around the tree base.', 'Flowers and fruits support coastal food webs.'],
                'references' => $references,
            ],
            'Bruguiera gymnorrhiza' => [
                'overview' => 'Bruguiera gymnorrhiza is a large-leaved mangrove often found in sheltered forests and river mouths. It can show knee-like root structures.',
                'physical_characteristics' => ['Large leathery leaves.', 'Buttress or knee-like root structures may occur.', 'Produces elongated propagules.'],
                'leaf_characteristics' => 'Leaves are opposite, large, glossy, and clustered toward branch tips.',
                'root_characteristics' => 'Knee roots and buttressing help support the tree and improve gas exchange.',
                'habitat' => ['River mouths', 'Sheltered mangrove forests', 'Estuaries', 'Inner mangrove zones'],
                'distribution' => ['Philippines', 'Southeast Asia', 'Indian Ocean region', 'Western Pacific region'],
                'ecological_importance' => $sharedEcology,
                'history' => $sharedHistory,
                'scientific_study' => $sharedStudy,
                'conservation_information' => $sharedConservation,
                'interesting_facts' => ['Knee roots can help identify Bruguiera in the field.', 'Large leaves add dense canopy cover.', 'Propagules are adapted for dispersal in tidal environments.'],
                'references' => $references,
            ],
            'Ceriops tagal' => [
                'overview' => 'Ceriops tagal is a mangrove species often found in sheltered and inner mangrove zones. It contributes to dense stands that stabilize coastal sediments.',
                'physical_characteristics' => ['Small to medium mangrove tree.', 'Compact growth in sheltered sites.', 'Elongated propagules.'],
                'leaf_characteristics' => 'Leaves are opposite, leathery, and clustered at branch ends.',
                'root_characteristics' => 'Root systems help bind muddy substrate and support the plant in tidal conditions.',
                'habitat' => ['Sheltered coasts', 'Muddy flats', 'Interior mangrove areas', 'Brackish intertidal zones'],
                'distribution' => ['Philippines', 'Southeast Asia', 'Indian Ocean coasts', 'Western Pacific coasts'],
                'ecological_importance' => $sharedEcology,
                'history' => $sharedHistory,
                'scientific_study' => $sharedStudy,
                'conservation_information' => $sharedConservation,
                'interesting_facts' => ['Can form dense stands in suitable inner mangrove zones.', 'Propagules help seedlings establish after tidal transport.', 'Adds habitat complexity in mixed mangrove forests.'],
                'references' => $references,
            ],
            'Excoecaria agallocha' => [
                'overview' => 'Excoecaria agallocha is a mangrove-associated tree often found near mangrove margins and brackish wetlands. Its milky sap can irritate skin and eyes.',
                'physical_characteristics' => ['Mangrove-associated tree with pale bark.', 'Milky sap that should be handled carefully.', 'Often occurs near landward margins.'],
                'leaf_characteristics' => 'Leaves are simple and may vary from green to reddish as they age.',
                'root_characteristics' => 'Rooting helps stabilize brackish wetland margins but lacks the large stilt roots of Rhizophora.',
                'habitat' => ['Mangrove margins', 'Tidal creeks', 'Brackish wetlands', 'Landward mangrove zones'],
                'distribution' => ['Philippines', 'Southeast Asia', 'South Asia', 'Northern Australia'],
                'ecological_importance' => $sharedEcology,
                'history' => $sharedHistory,
                'scientific_study' => $sharedStudy,
                'conservation_information' => $sharedConservation,
                'interesting_facts' => ['Its sap is traditionally noted as irritating and should not touch eyes.', 'Often grows at the landward edge of mangrove areas.', 'Supports coastal vegetation diversity.'],
                'references' => $references,
            ],
            'Xylocarpus granatum' => [
                'overview' => 'Xylocarpus granatum, often called cannonball mangrove, is known for large rounded fruit and presence in sheltered mangrove forests.',
                'physical_characteristics' => ['Mangrove tree with large round fruit.', 'Compound leaves.', 'Often develops a strong trunk in mature stands.'],
                'leaf_characteristics' => 'Leaves are compound, helping distinguish it from many simple-leaved mangroves.',
                'root_characteristics' => 'Root systems support the tree in sheltered tidal forest soils.',
                'habitat' => ['Riverine mangroves', 'Estuaries', 'Sheltered coastal forests', 'Tidal areas'],
                'distribution' => ['Philippines', 'Southeast Asia', 'Indian Ocean coasts', 'Western Pacific coasts'],
                'ecological_importance' => $sharedEcology,
                'history' => $sharedHistory,
                'scientific_study' => $sharedStudy,
                'conservation_information' => $sharedConservation,
                'interesting_facts' => ['Large round fruits inspired the common name cannonball mangrove.', 'Often associated with mature sheltered mangrove forests.', 'Adds canopy and structural diversity to mangrove stands.'],
                'references' => $references,
            ],
        ];
    }
}
