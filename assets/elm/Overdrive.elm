module Overdrive exposing (..)

import Array exposing (Array)
import Html exposing (..)
import Html.Attributes exposing (class, href, id, style)
import Json.Decode as JD
import Json.Decode.Pipeline exposing (decode, hardcoded, optional, required)
import Json.Encode as JE
import Material
import Material.Button as Button
import Material.Card as Card
import Material.Chip as Chip
import Material.Color as Color
import Material.Elevation as Elevation
import Material.Grid exposing (Device(..), cell, grid, size)
import Material.Helpers exposing (pure)
import Material.Icon as Icon
import Material.Layout as Layout
import Material.Options as Options exposing (css)
import Material.Scheme
import Material.Slider as Slider
import Material.Table as Table
import Material.Textfield as Textfield
import Material.Toggles as Toggle
import Phoenix
import Phoenix.Channel as Channel exposing (Channel)
import Phoenix.Push as Push
import Phoenix.Socket as Socket exposing (AbnormalClose, Socket)
import Time exposing (Time)


main : Program Never Model Msg
main =
    Html.program
        { init = ( init, Cmd.none )
        , view = view
        , subscriptions = subscriptions
        , update = update
        }



-- MODEL


type alias Momentum =
    { element : String
    , strength : Float
    }


type alias MomentumWithActor =
    { momentum : Momentum
    , actor : String
    }


type alias Actor =
    { name : String
    , currentHP : Int
    , maxHP : Int
    , currentMP : Int
    , maxMP : Int
    , currentLP : Int
    , maxLP : Int
    , currentDrive : Int
    , maxDrive : Int
    , initBase : Int
    , row : Row
    , status : List Status
    }


type Row
    = Front
    | Back


type alias Status =
    { status : String
    , duration : String
    , level : Int
    , meta : String
    }


type ConnectionStatus
    = Connected
    | Disconnected
    | ScheduledReconnect { time : Time }


type alias Model =
    { momenta : List Momentum
    , enemyMomenta : List Momentum
    , selectedMomentum : Momentum
    , selectedEnemyMomentum : Momentum
    , enemies : List Actor
    , players : List Actor
    , selectedActorIdx : Int
    , selectedActor : Actor
    , connectionStatus : ConnectionStatus
    , currentTime : Time
    , mdl : Material.Model
    , raised : Int
    }


init : Model
init =
    { momenta = []
    , enemyMomenta = []
    , selectedMomentum = Momentum "" 0
    , selectedEnemyMomentum = Momentum "" 0
    , players = []
    , enemies = []
    , selectedActorIdx = -1
    , selectedActor = Actor "Error" 0 0 0 0 0 0 0 0 0 Back []
    , connectionStatus = Disconnected
    , currentTime = 0
    , mdl = Material.model
    , raised = -1
    }



-- ACTION, UPDATE


type ActorType
    = Player
    | Enemy


type Msg
    = AddMomentum
    | AddEnemyMomentum
    | RemoveMomentum Momentum
    | RemoveEnemyMomentum Momentum
    | ClearMomentum
    | SetMomentumType String
    | SetMomentumStrength Float
    | SetEnemyMomentumType String
    | SetEnemyMomentumStrength Float
    | AddActor ActorType
    | ChangeSelectedActorName String
    | SelectActor Int
    | UnselectActor
    | Mdl (Material.Msg Msg)
    | Raise Int
    | Tick Time
    | MomentumUpdate JD.Value
    | ActorsUpdate JD.Value
    | SocketClosedAbnormally AbnormalClose
    | ConnectionStatusChanged ConnectionStatus


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AddMomentum ->
            let
                push =
                    Push.init "room:lobby" "new_momentum"
                        |> Push.withPayload
                            (JE.object
                                [ ( "element", JE.string model.selectedMomentum.element )
                                , ( "strength", JE.float model.selectedMomentum.strength )
                                , ( "actor", JE.string "player" )
                                ]
                            )
            in
            if model.selectedMomentum.element == "" then
                ( model, Cmd.none )
            else
                { model
                    | selectedMomentum = Momentum "" 0
                }
                    ! [ Phoenix.push lobbySocket push ]

        AddEnemyMomentum ->
            let
                push =
                    Push.init "room:lobby" "new_momentum"
                        |> Push.withPayload
                            (JE.object
                                [ ( "element", JE.string model.selectedEnemyMomentum.element )
                                , ( "strength", JE.float model.selectedEnemyMomentum.strength )
                                , ( "actor", JE.string "enemy" )
                                ]
                            )
            in
            if model.selectedEnemyMomentum.element == "" then
                ( model, Cmd.none )
            else
                { model
                    | selectedEnemyMomentum = Momentum "" 0
                }
                    ! [ Phoenix.push lobbySocket push ]

        RemoveMomentum momentum ->
            let
                push =
                    Push.init "room:lobby" "remove_momentum"
                        |> Push.withPayload
                            (JE.object
                                [ ( "element", JE.string momentum.element )
                                , ( "strength", JE.float momentum.strength )
                                , ( "actor", JE.string "player" )
                                ]
                            )
            in
            model ! [ Phoenix.push lobbySocket push ]

        RemoveEnemyMomentum momentum ->
            let
                push =
                    Push.init "room:lobby" "remove_momentum"
                        |> Push.withPayload
                            (JE.object
                                [ ( "element", JE.string momentum.element )
                                , ( "strength", JE.float momentum.strength )
                                , ( "actor", JE.string "enemy" )
                                ]
                            )
            in
            model ! [ Phoenix.push lobbySocket push ]

        ClearMomentum ->
            let
                push =
                    Push.init "room:lobby" "clear_momentum"
                        |> Push.withPayload JE.null
            in
            model ! [ Phoenix.push lobbySocket push ]

        SetMomentumType x ->
            ( { model | selectedMomentum = Momentum x model.selectedMomentum.strength }, Cmd.none )

        SetMomentumStrength x ->
            ( { model | selectedMomentum = Momentum model.selectedMomentum.element x }, Cmd.none )

        SetEnemyMomentumType x ->
            ( { model | selectedEnemyMomentum = Momentum x model.selectedEnemyMomentum.strength }, Cmd.none )

        SetEnemyMomentumStrength x ->
            ( { model | selectedEnemyMomentum = Momentum model.selectedEnemyMomentum.element x }, Cmd.none )

        AddActor actortype ->
            ( model, Cmd.none )

        ChangeSelectedActorName string ->
            ( model, Cmd.none )

        SelectActor actorIdx ->
            let
                selectedActorArray =
                    if actorIdx < 100 then
                        Array.fromList model.players
                    else
                        Array.fromList model.enemies

                selectedActorActualIndex =
                    if actorIdx < 100 then
                        actorIdx
                    else
                        actorIdx - 100

                maybeActor =
                    Array.get selectedActorActualIndex selectedActorArray
            in
            case maybeActor of
                Just actor ->
                    ( { model | selectedActorIdx = actorIdx, selectedActor = actor }, Cmd.none )

                Nothing ->
                    ( { model | selectedActorIdx = -1, selectedActor = Actor "Error" 0 0 0 0 0 0 0 0 0 Back [] }, Cmd.none )

        -- eventually this should also initiate a push of local changes to the server...
        UnselectActor ->
            ( { model | selectedActorIdx = -1, selectedActor = Actor "Error" 0 0 0 0 0 0 0 0 0 Back [] }, Cmd.none )

        Mdl msg_ ->
            Material.update Mdl msg_ model

        Raise k ->
            { model | raised = k } ! []

        MomentumUpdate payload ->
            case JD.decodeValue momentaDecoder payload of
                Ok momenta ->
                    let
                        _ =
                            Debug.log "ok" momenta

                        enemyMomenta =
                            List.filter (\mwa -> mwa.actor == "enemy") momenta
                                |> List.map (\mwa -> mwa.momentum)

                        playerMomenta =
                            List.filter (\mwa -> mwa.actor == "player") momenta
                                |> List.map (\mwa -> mwa.momentum)
                    in
                    { model | momenta = playerMomenta, enemyMomenta = enemyMomenta } ! []

                --( model, Cmd.none )
                Err err ->
                    let
                        _ =
                            Debug.log "err" err
                    in
                    model ! []

        ActorsUpdate payload ->
            case JD.decodeValue actorsDecoder payload of
                Ok actorsListContainer ->
                    let
                        _ =
                            Debug.log "ok! players: " actorsListContainer.players

                        _ =
                            Debug.log "enemies: " actorsListContainer.enemies
                    in
                    { model | players = actorsListContainer.players, enemies = actorsListContainer.enemies } ! []

                Err err ->
                    let
                        _ =
                            Debug.log "actorsUpdate err" ( err, payload )
                    in
                    model ! []

        SocketClosedAbnormally abnormalClose ->
            { model
                | connectionStatus =
                    ScheduledReconnect { time = roundDownToSecond (model.currentTime + abnormalClose.reconnectWait) }
            }
                ! []

        ConnectionStatusChanged status ->
            { model | connectionStatus = status } ! []

        Tick time ->
            { model | currentTime = time } ! []


roundDownToSecond : Time -> Time
roundDownToSecond ms =
    (ms / 1000) |> truncate |> (*) 1000 |> toFloat


type alias ActorsListContainer =
    { players : List Actor
    , enemies : List Actor
    }


actorsDecoder : JD.Decoder ActorsListContainer
actorsDecoder =
    JD.map2 (\players enemies -> ActorsListContainer players enemies)
        (JD.field "players" actorListDecoder)
        (JD.field "enemies" actorListDecoder)


actorListDecoder : JD.Decoder (List Actor)
actorListDecoder =
    JD.list actorDecoder


actorDecoder : JD.Decoder Actor
actorDecoder =
    decode Actor
        |> required "name" JD.string
        |> required "currHP" JD.int
        |> required "maxHP" JD.int
        |> required "currMP" JD.int
        |> required "maxMP" JD.int
        |> required "currLP" JD.int
        |> required "maxLP" JD.int
        |> required "currDrive" JD.int
        |> required "maxDrive" JD.int
        |> required "initBase" JD.int
        |> required "row" rowDecoder
        |> required "statuses" (JD.list statusDecoder)


rowDecoder : JD.Decoder Row
rowDecoder =
    JD.map
        (\row ->
            if row == "Front" then
                Front
            else
                Back
        )
        JD.string


statusDecoder : JD.Decoder Status
statusDecoder =
    JD.map4
        (\status duration level meta ->
            Status status duration level meta
        )
        (JD.field "status" JD.string)
        (JD.field "duration" JD.string)
        (JD.field "level" JD.int)
        (JD.field "meta" JD.string)


momentaDecoder : JD.Decoder (List MomentumWithActor)
momentaDecoder =
    JD.at [ "momenta" ] (JD.list momentumDecoder)


momentumDecoder : JD.Decoder MomentumWithActor
momentumDecoder =
    JD.map3 (\element strength actor -> MomentumWithActor (Momentum element strength) actor)
        (JD.field "element" JD.string)
        (JD.field "strength" JD.float)
        (JD.field "actor" JD.string)



-- SUBSCRIPTIONS


lobbySocket : String
lobbySocket =
    "ws://gaius.ddns.net:4000/socket/websocket"


socket : Socket Msg
socket =
    Socket.init lobbySocket
        |> Socket.onOpen (ConnectionStatusChanged Connected)
        |> Socket.onClose (\_ -> ConnectionStatusChanged Disconnected)
        |> Socket.onAbnormalClose SocketClosedAbnormally
        |> Socket.reconnectTimer (\backoffIteration -> (backoffIteration + 1) * 5000 |> toFloat)


lobby : String -> Channel Msg
lobby userName =
    Channel.init "room:lobby"
        |> Channel.withPayload (JE.object [ ( "user_name", JE.string "foobie" ) ])
        |> Channel.on "momentum_update" (\msg -> MomentumUpdate msg)
        |> Channel.on "status_update" (\msg -> ActorsUpdate msg)
        |> Channel.withDebug


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ phoenixSubscription model, Time.every Time.second Tick ]


phoenixSubscription model =
    Phoenix.connect socket [ lobby "foobie" ]



-- VIEW


type alias Mdl =
    Material.Model


view : Model -> Html Msg
view model =
    Material.Scheme.topWithScheme Color.Blue Color.Indigo <|
        Layout.render Mdl
            model.mdl
            [ Layout.fixedHeader
            , Layout.fixedDrawer
            ]
            { header = [ h1 [ style [ ( "padding", "1rem" ) ] ] [ text "S33D OVERDRIVE" ] ]
            , drawer = []
            , tabs = ( [], [] )
            , main =
                [ grid []
                    [ cell [ size All 3 ]
                        [ renderStatusList model Player ]
                    , cell [ size All 2 ]
                        [ renderPlayerMomentum model ]
                    , cell [ size All 2 ]
                        [ h4 [] [ text "Init List" ] ]
                    , cell [ size All 2 ]
                        [ renderEnemyMomentum model ]
                    , cell [ size All 3 ]
                        [ renderStatusList model Enemy ]
                    ]
                ]
            }


renderStatusList : Model -> ActorType -> Html Msg
renderStatusList model actortype =
    div
        []
        [ div []
            (List.map (statusCard model actortype)
                (if actortype == Player then
                    List.indexedMap (,) model.players
                 else
                    List.indexedMap (,) model.enemies
                )
            )
        , div []
            [ Button.render Mdl
                [ 998 ]
                model.mdl
                [ Button.fab
                , Button.colored
                , Options.css "margin-left" "92px"
                , Options.onClick (AddActor actortype)
                ]
                [ Icon.i "add" ]
            ]
        , div []
            (editActor model actortype)
        ]


editActor : Model -> ActorType -> List (Html Msg)
editActor model actortype =
    let
        playerSelected =
            model.selectedActorIdx < 100

        shouldDisplay =
            ((playerSelected && (actortype == Player)) || (not playerSelected && (actortype == Enemy))) && not (model.selectedActorIdx == -1)

        data =
            [ ( 1, "HP", model.selectedActor.currentHP, model.selectedActor.maxHP )
            , ( 2, "MP", model.selectedActor.currentMP, model.selectedActor.maxMP )
            , ( 3, "LP", model.selectedActor.currentLP, model.selectedActor.maxLP )
            , ( 4, "DR", model.selectedActor.currentDrive, model.selectedActor.maxDrive )
            ]
    in
    if shouldDisplay then
        [ Button.render Mdl
            [ 999 ]
            model.mdl
            [ Button.raised
            , Button.colored
            , Button.ripple
            , Options.css "margin-left" "87px"
            , Options.css "margin-top" "10px"
            , Options.onClick UnselectActor
            ]
            [ text "SAVE" ]
        , div []
            [ Textfield.render Mdl
                [ 800 ]
                model.mdl
                [ Textfield.value model.selectedActor.name
                , Options.onInput ChangeSelectedActorName
                , Options.input
                    [ Options.css "text-align" "center"
                    ]
                ]
                []
            ]
        , Table.table []
            [ Table.thead []
                [ Table.tr []
                    [ Table.th [] [ text "" ]
                    , Table.th [] [ text "CURR" ]
                    , Table.th [] [ text "MAX" ]
                    , Table.th [] [ text "±" ]
                    ]
                ]
            , Table.tbody []
                (data
                    |> List.map
                        (\( id, label, curr, max ) ->
                            Table.tr []
                                [ Table.td [] [ text label ]
                                , Table.td [] [ statTextField model (id * 10) curr ]
                                , Table.td [] [ statTextField model (id * 100) max ]
                                , Table.td [] [ text "+", text "-" ]
                                ]
                        )
                )
            ]
        ]
    else
        [ text "" ]


statTextField : Model -> Int -> Int -> Html Msg
statTextField model fieldId value =
    div
        []
        [ Textfield.render Mdl
            [ model.selectedActorIdx + fieldId ]
            model.mdl
            [ Textfield.value (value |> toString)
            , Textfield.maxlength 3
            , Options.css "width" "30px"
            , Options.input
                [ Options.css "text-align" "right"
                , Options.css "width" "30px"
                ]
            ]
            []
        ]


dynamic : Int -> Msg -> Model -> Options.Style Msg
dynamic k action model =
    [ if model.raised == k then
        Elevation.e8
      else
        Elevation.e2
    , Elevation.transition 250
    , Options.onMouseEnter (Raise k)
    , Options.onMouseLeave (Raise -1)
    , Options.onClick action
    ]
        |> Options.many


statusCard : Model -> ActorType -> ( Int, Actor ) -> Html Msg
statusCard model actortype ( k, actor ) =
    let
        dyn_id =
            k
                + (if actortype == Player then
                    0
                   else
                    100
                  )
    in
    Card.view
        [ dynamic dyn_id (SelectActor dyn_id) model
        , css "width" "240px"
        , css "margin" "4px 8px 4px 0px"
        , Color.background (Color.color Color.Blue Color.S500)
        ]
        [ Card.title [ css "padding" "5px 8px 0px 8px" ] [ Card.head [ Color.text Color.white ] [ text actor.name ] ]
        , Card.text [ Color.text Color.white, css "padding" "0px 8px 8px 8px" ]
            [ div []
                [ renderStat model "HP" actor.currentHP actor.maxHP actortype
                , renderStat model "MP" actor.currentMP actor.maxMP actortype
                , renderStat model "LP" actor.currentLP actor.maxLP actortype
                , renderStat model "DR" actor.currentDrive actor.maxDrive actortype
                , renderStatus actor
                ]
            ]
        ]


statDiv : Int -> Int -> String
statDiv c m =
    round ((toFloat c / toFloat m) * 100)
        |> toString


renderStat : Model -> String -> Int -> Int -> ActorType -> Html Msg
renderStat model label currentStat maxStat actortype =
    div []
        [ if actortype == Player then
            text (label ++ "   " ++ (toString <| currentStat) ++ "/" ++ (toString <| maxStat))
          else
            text (label ++ "   " ++ statDiv currentStat maxStat ++ "%")
        ]


renderStatus : Actor -> Html Msg
renderStatus actor =
    div [] [ text "No Statuses" ]


renderEnemyMomentum : Model -> Html Msg
renderEnemyMomentum model =
    div []
        [ renderEnemyMomenta model.enemyMomenta
        , div []
            [ addMomentumInput model model.selectedEnemyMomentum SetEnemyMomentumStrength SetEnemyMomentumType "enemy" 100
            , Button.render Mdl
                [ 1 ]
                model.mdl
                [ Options.onClick AddEnemyMomentum ]
                [ text ("Add " ++ printMomentum model.selectedEnemyMomentum) ]
            ]
        , div []
            [ Button.render Mdl
                [ 0 ]
                model.mdl
                [ Options.onClick ClearMomentum
                ]
                [ text "Clear Momentum" ]
            ]
        ]


renderPlayerMomentum : Model -> Html Msg
renderPlayerMomentum model =
    div []
        [ renderMomenta model.momenta
        , div []
            [ addMomentumInput model model.selectedMomentum SetMomentumStrength SetMomentumType "player" 0
            , Button.render Mdl
                [ 1 ]
                model.mdl
                [ Options.onClick AddMomentum ]
                [ text ("Add " ++ printMomentum model.selectedMomentum) ]
            ]
        , div []
            [ Button.render Mdl
                [ 0 ]
                model.mdl
                [ Options.onClick ClearMomentum
                ]
                [ text "Clear Momentum" ]
            ]
        ]


printMomentum : Momentum -> String
printMomentum m =
    if not (m.element == "") then
        if not (m.strength == 0) then
            m.element ++ " +" ++ toString m.strength
        else
            m.element
    else
        ""


addMomentumInput : Model -> Momentum -> (Float -> Msg) -> (String -> Msg) -> String -> Int -> Html Msg
addMomentumInput model momentum setMomentumStrengthFunction setMomentumElementFunction mRadioGroup idBase =
    div []
        [ div []
            [ makeMomentumRadio model (idBase + 2) "Fire" momentum setMomentumElementFunction mRadioGroup
            , makeMomentumRadio model (idBase + 3) "Water" momentum setMomentumElementFunction mRadioGroup
            , makeMomentumRadio model (idBase + 4) "Earth" momentum setMomentumElementFunction mRadioGroup
            , makeMomentumRadio model (idBase + 5) "Air" momentum setMomentumElementFunction mRadioGroup
            ]
        , div []
            [ makeMomentumRadio model (idBase + 6) "Launch" momentum setMomentumElementFunction mRadioGroup
            , makeMomentumRadio model (idBase + 7) "Pin" momentum setMomentumElementFunction mRadioGroup
            , makeMomentumRadio model (idBase + 8) "Rush" momentum setMomentumElementFunction mRadioGroup
            ]
        , div []
            [ makeMomentumRadio model (idBase + 9) "Recovery" momentum setMomentumElementFunction mRadioGroup
            , makeMomentumRadio model (idBase + 10) "Supreme" momentum setMomentumElementFunction mRadioGroup
            ]
        , div []
            [ Slider.view
                [ Slider.onChange setMomentumStrengthFunction
                , Slider.value momentum.strength
                , Slider.max 10
                , Slider.min 0
                , Slider.step 1
                ]
            ]
        ]


makeMomentumRadio : Model -> Int -> String -> Momentum -> (String -> Msg) -> String -> Html Msg
makeMomentumRadio model instance momentumLabel momentum setMomentumElementFunction mRadioGroup =
    Toggle.radio Mdl
        [ instance ]
        model.mdl
        [ Toggle.value (momentumLabel == momentum.element)
        , Toggle.group mRadioGroup
        , Toggle.ripple
        , Options.onToggle (setMomentumElementFunction momentumLabel)
        , Options.css "margin" "3px 3px"
        ]
        [ text momentumLabel ]


renderMomenta : List Momentum -> Html Msg
renderMomenta momenta =
    div
        []
        [ div [] (List.map toChip momenta)
        ]


renderEnemyMomenta : List Momentum -> Html Msg
renderEnemyMomenta momenta =
    div
        []
        [ div [] (List.map toEnemyChip momenta)
        ]


toChip : Momentum -> Html Msg
toChip momentum =
    Chip.span
        [ Options.css "margin" "5px 5px"
        , Chip.deleteIcon "cancel"
        , Chip.deleteClick (RemoveMomentum momentum)
        ]
        [ Chip.content [] [ text (printMomentum momentum) ] ]


toEnemyChip : Momentum -> Html Msg
toEnemyChip momentum =
    Chip.span
        [ Options.css "margin" "5px 5px"
        , Chip.deleteIcon "cancel"
        , Chip.deleteClick (RemoveEnemyMomentum momentum)
        ]
        [ Chip.content [] [ text (printMomentum momentum) ] ]
