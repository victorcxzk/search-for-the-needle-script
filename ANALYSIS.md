# Engenharia Reversa — Search For The Needle

## Resumo do Jogo
- **PlaceId Hub/Lobby**: 77108422251420
- **PlaceId Farmhouse (Gameplay)**: 108628039999641
- **PlaceId Basement (Gameplay)**: 83445806734780
- **Desenvolvedor**: Garage Games (GroupId: 279288859)

## Estrutura de Dados do Jogador (template)
```lua
{
    Wins = 0,
    Gems = 0,
    AlienCoins = 0,
    TutorialCompleted = false,
    AlienChestCredits = 0,
    ActiveClass = "Starter",
    ActiveClassSlot = 1,
    OwnedClassSlots = 1,
    BestTime = 9999,
    TotalPlaytime = 0,
    TotalHayCollected = 0,
    TotalClassSpins = 0,
    DailyRewardsStart = 0,
    GroupRewardClaimed = false,
    EquippedPet = "",
    LastEquippedSkin = "",
    RedeemedCodes = {},
    ClassSlots = {},
    BestTimes = {},
    ShopItemsBought = {},
    PurchaseHistory = {},
    PlayerUpgrades = {
        ExtraHoldAmount = 0,
        GemValue = 0,
        ExtraHayValuePercentage = 0,
        ExtraTakeAmount = 0
    },
    DailyRewardsClaimed = {},
    OwnedPets = {},
    OwnedSkins = {},
    EquippedSkins = {},
}
```

## RemoteFunctions Chave
| Remote | Uso |
|--------|-----|
| `ReplicatedStorage.EventChest.OpenChest` | Abrir baus alien |
| `ReplicatedStorage.SkinSystem.EquipSkin` | Equipar skin |
| `ReplicatedStorage.PetSystem.EquipPet` | Equipar pet |
| `ReplicatedStorage.ClassSystem.SelectClassSlot` | Selecionar slot de classe |
| `ReplicatedStorage.ClassSystem.RollClass` | Girar roleta de classe |
| `ReplicatedStorage.CodeSystem.RedeemCode` | Resgatar codigos |

## Networker Services (via RemoteEvent/RemoteFunction pairs)
- DailyRewards, MonetizationService, LoadingUIService
- InformationService, TimeBoard, AnimationService
- PlayerStats, ShopUI, EffectService
- PartyService, SoundService, GroupReward, ScreenEffectService

## Classes e Pesos
| Classe | Peso | Bonus |
|--------|------|-------|
| Starter | 40% | Nenhum |
| Pack Mule | 25% | +50% capacidade |
| Hay Merchant | 14% | +20% valor do feno |
| Forkmaster | 9% | +25% scoop, -25% custo upgrade |
| Demolitionist | 7% | +20% raio explosao |
| Prospector | 3.9% | 1.5x chance gema |
| Drone Specialist | 1% | Drone permanente, +30% vel, +40% cap |
| Ultimate Farmer | raro | Bonus maximo |

## Pets
| Pet | Capacidade | TakeAmount | Speed | SellsInPlace |
|-----|-----------|------------|-------|--------------|
| Chicken | 54 | 6 | 6.5 | false |
| Cow | 180 | 20 | 5.5 | true |

## Upgrades (Gems)
| Upgrade | DataKey | Efeito | Precos |
|---------|---------|--------|--------|
| BAG SIZE | ExtraHoldAmount | +5 bag/lvl | 25,50,75,100,150,450 |
| HAND GRAB | ExtraTakeAmount | +1 hay/lvl | 50,120,240,500 |
| GEM VALUE | GemValue | +1 gem/lvl | 150,400,800,1400 |
| HAY VALUE | ExtraHayValuePercentage | +10%/lvl | 20,40,60,100,150,450 |

## Mapas
| Mapa | PlaceId | Ordem | Requisito |
|------|---------|-------|-----------|
| Farmhouse | 108628039999641 | 1 | Nenhum |
| Basement | 83445806734780 | 2 | 1 Win (HARD: 2 Wins) |

## Ferramentas
- Pitchfork (forcado) - coleta feno
- Dynamite/TNT - explode feno
- Vacuum (aspirador) - suga feno
- Drone - coleta automatica

---

## GAMEPLAY PLACE (PlaceId: 108628039999641)

### RemoteEvents de Gameplay (42 total)
| Remote | Direcao | Uso |
|--------|---------|-----|
| NeedleHaystack.PickHay | Client->Server | Coletar feno |
| NeedleHaystack.PickDroppedHay | Client->Server | Coletar feno caido |
| NeedleHaystack.DropHay | Client->Server | Soltar feno |
| NeedleHaystack.SellHay | Client->Server | Vender feno |
| NeedleHaystack.HaySold | Server->Client | Confirmacao venda |
| NeedleHaystack.BuyUpgrade | Client->Server | Comprar upgrade |
| NeedleHaystack.UpgradeChanged | Server->Client | Upgrade aplicado |
| NeedleHaystack.PitchforkDig | Client->Server | Cavar com forcado |
| NeedleHaystack.PitchforkDug | Server->Client | Resultado escavacao |
| NeedleHaystack.TntAction | Client->Server | Jogar TNT |
| NeedleHaystack.TntExploded | Server->Client | Explosao TNT |
| NeedleHaystack.VacuumAction | Client->Server | Usar aspirador |
| NeedleHaystack.VacuumHarvested | Server->Client | Aspirador coletou |
| NeedleHaystack.DeployDrone | Client->Server | Deployar drone |
| NeedleHaystack.DroneHarvested | Server->Client | Drone coletou |
| NeedleHaystack.DroneSold | Server->Client | Drone vendeu |
| NeedleHaystack.CollectGem | Client->Server | Coletar gema |
| NeedleHaystack.GemSpawned | Server->Client | Gema apareceu |
| NeedleHaystack.GemCollected | Server->Client | Gema confirmada |
| NeedleHaystack.NeedleFound | Server->Client | Agulha encontrada |
| NeedleHaystack.NeedleHandIn | Client->Server | Entregar agulha |
| NeedleHaystack.NeedleTargetChanged | Server->Client | Posicao agulha |
| NeedleHaystack.NeedleRoundCompleted | Server->Client | Rodada completa |
| NeedleHaystack.BuyShopItem | Client->Server | Comprar item loja |
| NeedleHaystack.ShopPurchaseResult | Server->Client | Resultado compra |
| NeedleHaystack.HeldToolState | Client->Server | Estado ferramenta |
| NeedleHaystack.ClassEffect | Server->Client | Efeito de classe |
| NeedleHaystack.IntroCutsceneFinished | Client->Server | Pular intro |
| NeedleHaystack.TutorialCompleted | Client->Server | Pular tutorial |
| NeedleHaystack.ReturnToLobby | Client->Server | Voltar ao lobby |
| NeedleHaystack.AdminGiveNeedle | Admin only | Dar agulha |

### RemoteFunctions de Gameplay
| Remote | Uso |
|--------|-----|
| NeedleHaystack.GetHayState | Obter estado do feno |
| NeedleHaystack.GetUpgradeState | Obter estado upgrades |
| NeedleHaystack.ClassDebug | Debug de classes |

### Config de Dificuldade
| Param | NORMAL | HARD |
|-------|--------|------|
| HayScale | 1 | 3 |
| PileScale | 1 | 1.5 |
| RenderedHay | 13000 | 19500 |
| NeedleRevealFraction | 0.75 | 0.67 |
| WinGemReward | 120 | 300 |
| AlienCoinsMin | 100 | 150 |
| AlienCoinsMax | 250 | 500 |
| GemLimit | 200 | 400 |
| UpgradeCostMultiplier | 1 | 1.25 |

### GemConfig
- SURFACE_CHANCE: 0.002295
- DEPTH_CHANCE: 0.00306
- COLLECT_DISTANCE: 30
- ROUND_BASE_VALUE: 100

### Mecanica de Feno (Surface module)
- Pilha circular com raio = PILE_RADIUS
- Grid de escavacao: DIG_GRID_RESOLUTION x DIG_GRID_RESOLUTION celulas
- Profundidade maxima: PITCHFORK_MAX_DEPTH (~4.1)
- Agulha revelada quando NeedleRevealFraction do feno removido

### HeldToolState Args
- FireServer(toolName, phase)
- toolName: "Pitchfork", "Tnt", "Vacuum", "Drone", nil
- phase: "idle", "dig", "throw", "suck", etc.

## CharacterConfig
- WalkSpeed: 20
- JumpHeight: 7.2

## Chest Event (Alien)
- Custo: 100 AlienCoins
- Bundles Robux: 3(59R$), 5(99R$), 10(179R$)
