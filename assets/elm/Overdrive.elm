module Overdrive exposing (..)

import Array exposing (Array)
import Dict
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
import Material.List as Lists
import Material.Menu as Menu
import Material.Options as Options exposing (css)
import Material.Scheme
import Material.Slider as Slider
import Material.Table as Table
import Material.Textfield as Textfield
import Material.Toggles as Toggle
import Material.Tooltip as Tooltip
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


type alias InitRecord =
    { name : String
    , idx : Int
    }


type alias Actor =
    { uuid : String
    , name : String
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
    , selectedStatus : Status
    , inits : List InitRecord
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
    , selectedActor = Actor "." "Error" 0 0 0 0 0 0 0 0 0 Back []
    , selectedStatus = Status "" "" 0 ""
    , inits = []
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
    | RemoveActor
    | ChangeSelectedActorName String
    | ChangeSelectedActorMaxHP Int
    | ChangeSelectedActorCurrentHP Int
    | ChangeSelectedActorMaxMP Int
    | ChangeSelectedActorCurrentMP Int
    | ChangeSelectedActorMaxLP Int
    | ChangeSelectedActorCurrentLP Int
    | ChangeSelectedActorMaxDrive Int
    | ChangeSelectedActorCurrentDrive Int
    | ChangeSelectedActorBaseInit Int
    | ToggleSelectedActorRow
    | RemoveSelectedModelStatus Status
    | AddSelectedModelStatus
    | ChangeSelectedStatusName String
    | ChangeSelectedStatusDuration String
    | ChangeSelectedStatusLevel Int
    | ChangeSelectedStatusMeta String
    | SelectActor Int
    | SaveActorChanges
    | ClearActorChanges
    | IncrementInitRecord Int
    | DecrementInitRecord Int
    | InitialiseInitRecords
    | ClearInitRecords
    | Mdl (Material.Msg Msg)
    | Raise Int
    | Tick Time
    | MomentumUpdate JD.Value
    | ActorsUpdate JD.Value
    | InitRecordsUpdate JD.Value
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
            let
                push =
                    Push.init "room:lobby" "add_actor"
                        |> Push.withPayload
                            (JE.object
                                [ ( "team"
                                  , JE.string
                                        (if actortype == Player then
                                            "player"
                                         else
                                            "enemy"
                                        )
                                  )
                                ]
                            )
            in
            model ! [ Phoenix.push lobbySocket push ]

        RemoveActor ->
            let
                push =
                    Push.init "room:lobby" "remove_actor"
                        |> Push.withPayload
                            (JE.object
                                [ ( "uuid", JE.string model.selectedActor.uuid ) ]
                            )
            in
            { model | selectedActorIdx = -1, selectedActor = Actor "." "Error" 0 0 0 0 0 0 0 0 0 Back [] } ! [ Phoenix.push lobbySocket push ]

        ChangeSelectedActorName name ->
            let
                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor | name = name }
            in
            ( { model | selectedActor = newSelectedActor }, Cmd.none )

        ChangeSelectedActorMaxHP stat ->
            let
                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor | maxHP = stat }
            in
            ( { model | selectedActor = newSelectedActor }, Cmd.none )

        ChangeSelectedActorCurrentHP stat ->
            let
                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor
                        | currentHP =
                            if stat <= model.selectedActor.maxHP then
                                if stat < 0 then
                                    0
                                else
                                    stat
                            else
                                model.selectedActor.maxHP
                    }
            in
            ( { model | selectedActor = newSelectedActor }, Cmd.none )

        ChangeSelectedActorMaxMP stat ->
            let
                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor | maxMP = stat }
            in
            ( { model | selectedActor = newSelectedActor }, Cmd.none )

        ChangeSelectedActorCurrentMP stat ->
            let
                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor
                        | currentMP =
                            if stat <= model.selectedActor.maxMP then
                                if stat < 0 then
                                    0
                                else
                                    stat
                            else
                                model.selectedActor.maxMP
                    }
            in
            ( { model | selectedActor = newSelectedActor }, Cmd.none )

        ChangeSelectedActorMaxLP stat ->
            let
                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor | maxLP = stat }
            in
            ( { model | selectedActor = newSelectedActor }, Cmd.none )

        ChangeSelectedActorCurrentLP stat ->
            let
                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor
                        | currentLP =
                            if stat <= model.selectedActor.maxLP then
                                if stat < 0 then
                                    0
                                else
                                    stat
                            else
                                model.selectedActor.maxLP
                    }
            in
            ( { model | selectedActor = newSelectedActor }, Cmd.none )

        ChangeSelectedActorMaxDrive stat ->
            let
                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor | maxDrive = stat }
            in
            ( { model | selectedActor = newSelectedActor }, Cmd.none )

        ChangeSelectedActorCurrentDrive stat ->
            let
                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor
                        | currentDrive =
                            if stat < 0 then
                                0
                            else
                                stat
                    }
            in
            ( { model | selectedActor = newSelectedActor }, Cmd.none )

        ChangeSelectedActorBaseInit stat ->
            let
                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor | initBase = stat }
            in
            ( { model | selectedActor = newSelectedActor }, Cmd.none )

        ToggleSelectedActorRow ->
            let
                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor
                        | row =
                            if oldSelectedActor.row == Front then
                                Back
                            else
                                Front
                    }
            in
            ( { model | selectedActor = newSelectedActor }, Cmd.none )

        RemoveSelectedModelStatus status ->
            let
                newStatusList =
                    List.filter (\s -> s /= status) model.selectedActor.status

                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor | status = newStatusList }
            in
            { model | selectedActor = newSelectedActor } ! []

        AddSelectedModelStatus ->
            let
                status =
                    model.selectedStatus

                valid =
                    status.status /= "" && status.duration /= "" && status.level > 0

                newStatusList =
                    model.selectedActor.status ++ [ Status status.status status.duration status.level status.meta ]

                oldSelectedActor =
                    model.selectedActor

                newSelectedActor =
                    { oldSelectedActor | status = newStatusList }
            in
            if valid then
                { model | selectedActor = newSelectedActor, selectedStatus = Status "" "" 0 "" } ! []
            else
                ( model, Cmd.none )

        ChangeSelectedStatusName status ->
            { model | selectedStatus = Status status model.selectedStatus.duration model.selectedStatus.level model.selectedStatus.meta } ! []

        ChangeSelectedStatusDuration duration ->
            { model | selectedStatus = Status model.selectedStatus.status duration model.selectedStatus.level model.selectedStatus.meta } ! []

        ChangeSelectedStatusLevel level ->
            { model | selectedStatus = Status model.selectedStatus.status model.selectedStatus.duration level model.selectedStatus.meta } ! []

        ChangeSelectedStatusMeta meta ->
            { model | selectedStatus = Status model.selectedStatus.status model.selectedStatus.duration model.selectedStatus.level meta } ! []

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
                    ( { model | selectedActorIdx = -1, selectedActor = Actor "." "Error" 0 0 0 0 0 0 0 0 0 Back [] }, Cmd.none )

        SaveActorChanges ->
            let
                push =
                    Push.init "room:lobby" "save_actor"
                        |> Push.withPayload
                            (JE.object
                                [ ( "uuid", JE.string model.selectedActor.uuid )
                                , ( "name", JE.string model.selectedActor.name )
                                , ( "team"
                                  , if model.selectedActorIdx < 100 then
                                        JE.string "player"
                                    else
                                        JE.string "enemy"
                                  )
                                , ( "currHP", JE.int model.selectedActor.currentHP )
                                , ( "maxHP", JE.int model.selectedActor.maxHP )
                                , ( "currMP", JE.int model.selectedActor.currentMP )
                                , ( "maxMP", JE.int model.selectedActor.maxMP )
                                , ( "currLP", JE.int model.selectedActor.currentLP )
                                , ( "maxLP", JE.int model.selectedActor.maxLP )
                                , ( "currDrive", JE.int model.selectedActor.currentDrive )
                                , ( "maxDrive", JE.int model.selectedActor.maxDrive )
                                , ( "initBase", JE.int model.selectedActor.initBase )
                                , ( "row"
                                  , if model.selectedActor.row == Front then
                                        JE.string "Front"
                                    else
                                        JE.string "Back"
                                  )
                                , ( "statuses", JE.list (List.map statusEncoder model.selectedActor.status) )
                                ]
                            )
            in
            { model | selectedActorIdx = -1, selectedActor = Actor "." "Error" 0 0 0 0 0 0 0 0 0 Back [] } ! [ Phoenix.push lobbySocket push ]

        ClearActorChanges ->
            { model | selectedActorIdx = -1, selectedActor = Actor "." "Error" 0 0 0 0 0 0 0 0 0 Back [] } ! []

        InitialiseInitRecords ->
            let
                push =
                    Push.init "room:lobby" "initialise_init"
                        |> Push.withPayload JE.null
            in
            model ! [ Phoenix.push lobbySocket push ]

        ClearInitRecords ->
            let
                push =
                    Push.init "room:lobby" "clear_init"
                        |> Push.withPayload JE.null
            in
            model ! [ Phoenix.push lobbySocket push ]

        IncrementInitRecord idx ->
            let
                push =
                    Push.init "room:lobby" "increment_init"
                        |> Push.withPayload
                            (JE.object
                                [ ( "idx", JE.int idx ) ]
                            )
            in
            model ! [ Phoenix.push lobbySocket push ]

        DecrementInitRecord idx ->
            let
                push =
                    Push.init "room:lobby" "decrement_init"
                        |> Push.withPayload
                            (JE.object
                                [ ( "idx", JE.int idx ) ]
                            )
            in
            model ! [ Phoenix.push lobbySocket push ]

        Mdl msg_ ->
            Material.update Mdl msg_ model

        Raise k ->
            { model | raised = k } ! []

        MomentumUpdate payload ->
            case JD.decodeValue momentaDecoder payload of
                Ok momenta ->
                    let
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
                            Debug.log "momentumUpdate err" ( err, payload )
                    in
                    model ! []

        ActorsUpdate payload ->
            case JD.decodeValue actorsDecoder payload of
                Ok actorsListContainer ->
                    { model | players = actorsListContainer.players, enemies = actorsListContainer.enemies } ! []

                Err err ->
                    let
                        _ =
                            Debug.log "actorsUpdate err" ( err, payload )
                    in
                    model ! []

        InitRecordsUpdate payload ->
            case JD.decodeValue initsDecoder payload of
                Ok inits ->
                    { model | inits = inits } ! []

                Err err ->
                    let
                        _ =
                            Debug.log "initsUpdate err" ( err, payload )
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


initsDecoder : JD.Decoder (List InitRecord)
initsDecoder =
    JD.at [ "inits" ] (JD.list initDecoder)


initDecoder : JD.Decoder InitRecord
initDecoder =
    decode InitRecord
        |> required "name" JD.string
        |> required "idx" JD.int


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
        |> required "uuid" JD.string
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


statusEncoder : Status -> JE.Value
statusEncoder status =
    JE.object
        [ ( "status", JE.string status.status )
        , ( "duration", JE.string status.duration )
        , ( "level", JE.int status.level )
        , ( "meta", JE.string status.meta )
        ]


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
        |> Channel.on "inits_update" (\msg -> InitRecordsUpdate msg)
        |> Channel.withDebug


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ phoenixSubscription model, Time.every Time.second Tick, Menu.subs Mdl model.mdl ]


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
                        [ renderInitList model ]
                    , cell [ size All 2 ]
                        [ renderEnemyMomentum model ]
                    , cell [ size All 3 ]
                        [ renderStatusList model Enemy ]
                    ]
                ]
            }


renderInitList : Model -> Html Msg
renderInitList model =
    div []
        [ Button.render Mdl
            [ 53524 ]
            model.mdl
            [ Button.raised
            , Button.colored
            , Button.ripple
            , Options.css "margin-left" "16px"
            , Options.onClick InitialiseInitRecords
            ]
            [ text "INITIALISE" ]
        , Button.render Mdl
            [ 53525 ]
            model.mdl
            [ Button.raised
            , Button.colored
            , Button.ripple
            , Options.css "margin-left" "3px"
            , Options.onClick ClearInitRecords
            ]
            [ text "CLEAR" ]
        , Lists.ul []
            (List.map (renderInit model) model.inits)
        ]


renderInit : Model -> InitRecord -> Html Msg
renderInit model record =
    let
        plus model k =
            Button.render Mdl
                [ k ]
                model.mdl
                [ Button.icon
                , Options.onClick (IncrementInitRecord k)
                ]
                [ Icon.i "arrow_drop_up" ]

        minus model k =
            Button.render Mdl
                [ k ]
                model.mdl
                [ Button.icon
                , Options.onClick (DecrementInitRecord k)
                ]
                [ Icon.i "arrow_drop_down" ]
    in
    Lists.li []
        [ minus model record.idx
        , Lists.content [] [ text record.name ]
        , plus model record.idx
        ]



--div [] [ text ("init! " ++ record.name ++ toString record.idx) ]


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
            [ ( 1, "HP", model.selectedActor.currentHP, model.selectedActor.maxHP, ChangeSelectedActorCurrentHP, ChangeSelectedActorMaxHP )
            , ( 2, "MP", model.selectedActor.currentMP, model.selectedActor.maxMP, ChangeSelectedActorCurrentMP, ChangeSelectedActorMaxMP )
            , ( 3, "LP", model.selectedActor.currentLP, model.selectedActor.maxLP, ChangeSelectedActorCurrentLP, ChangeSelectedActorMaxLP )
            , ( 4, "Drive", model.selectedActor.currentDrive, model.selectedActor.maxDrive, ChangeSelectedActorCurrentDrive, ChangeSelectedActorMaxDrive )
            ]
    in
    if shouldDisplay then
        [ Button.render Mdl
            [ 999 ]
            model.mdl
            [ Button.raised
            , Button.colored
            , Button.ripple
            , Options.css "margin-left" "12px"
            , Options.css "margin-top" "10px"
            , Options.onClick SaveActorChanges
            ]
            [ text "SAVE" ]
        , Button.render Mdl
            [ 665 ]
            model.mdl
            [ Button.raised
            , Button.colored
            , Button.ripple
            , Options.css "margin-left" "3px"
            , Options.css "margin-top" "10px"
            , Options.onClick ClearActorChanges
            ]
            [ text "RESET" ]
        , Button.render Mdl
            [ 666 ]
            model.mdl
            [ Button.raised
            , Button.colored
            , Button.ripple
            , Options.css "margin-left" "3px"
            , Options.css "margin-top" "10px"
            , Options.onClick RemoveActor
            ]
            [ text "DELETE" ]
        , div []
            [ Textfield.render Mdl
                [ 800 ]
                model.mdl
                [ Textfield.value model.selectedActor.name
                , Options.onInput ChangeSelectedActorName
                , Options.css "width" "255px"
                , Options.input
                    [ Options.css "text-align" "center"
                    , Options.css "width" "255px"
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
                        (\( id, label, curr, max, currAction, maxAction ) ->
                            Table.tr []
                                [ Table.td [] [ text label ]
                                , Table.td [] [ statTextField model (id * 10) curr currAction ]
                                , Table.td [] [ statTextField model (id * 100) max maxAction ]
                                , Table.td [] [ plusMinusField model curr max currAction ]
                                ]
                        )
                )
            , Table.tr []
                [ Table.td [] [ text "Init" ]
                , Table.td [] [ statTextField model 142526 model.selectedActor.initBase ChangeSelectedActorBaseInit ]
                , Table.td [] [ text "" ]
                , Table.td [] [ text "" ]
                ]
            ]
        , Toggle.switch Mdl
            [ 774 ]
            model.mdl
            [ Options.onToggle ToggleSelectedActorRow
            , Toggle.ripple
            , Toggle.value
                (if model.selectedActor.row == Front then
                    True
                 else
                    False
                )
            ]
            [ text
                (if model.selectedActor.row == Front then
                    "Front"
                 else
                    "Back"
                )
            ]
        , renderEditStatusList model
        , Textfield.render Mdl
            [ 84764 ]
            model.mdl
            [ Textfield.label "New Status Metadata"
            , Textfield.floatingLabel
            , Textfield.value model.selectedStatus.meta
            , Options.input
                [ Options.css "text-align" "center"
                ]
            , Options.onInput ChangeSelectedStatusMeta
            ]
            []
        ]
    else
        [ text "" ]


changeStatusMenuItem : String -> Menu.Item Msg
changeStatusMenuItem string =
    Menu.item
        [ Menu.onSelect (ChangeSelectedStatusName string) ]
        [ text string ]


renderEditStatusList : Model -> Html Msg
renderEditStatusList model =
    let
        printableLevel =
            if model.selectedStatus.level > 0 then
                if model.selectedStatus.level == 1 then
                    "I"
                else
                    "II"
            else
                ""
    in
    Lists.ul []
        (List.map (renderEditStatusListItem model) model.selectedActor.status
            ++ [ Lists.li []
                    [ Lists.content []
                        [ Menu.render Mdl
                            [ 7854625 ]
                            model.mdl
                            [ Menu.topRight ]
                            [ changeStatusMenuItem "Energize"
                            , changeStatusMenuItem "Focus"
                            , changeStatusMenuItem "Lucky"
                            , changeStatusMenuItem "Kinetic-Power"
                            , changeStatusMenuItem "Elemental-Power"
                            , changeStatusMenuItem "Healing-Power"
                            , changeStatusMenuItem "Kinetic-Guard"
                            , changeStatusMenuItem "Elemental-Guard"
                            , changeStatusMenuItem "Stalwart"
                            , changeStatusMenuItem "Liberation"
                            , changeStatusMenuItem "Element-Absorb"
                            , changeStatusMenuItem "Chill"
                            , changeStatusMenuItem "Exhaust"
                            , changeStatusMenuItem "Shock"
                            , changeStatusMenuItem "Curse"
                            , changeStatusMenuItem "Burning"
                            , changeStatusMenuItem "Kinetic-Shatter"
                            , changeStatusMenuItem "Elemental-Shatter"
                            , changeStatusMenuItem "Kinetic-Falter"
                            , changeStatusMenuItem "Elemental-Falter"
                            , changeStatusMenuItem "Toxin"
                            , changeStatusMenuItem "Taunt"
                            , changeStatusMenuItem "Challenge"
                            ]
                        , text model.selectedStatus.status
                        , Menu.render Mdl
                            [ 7854626 ]
                            model.mdl
                            [ Menu.bottomLeft ]
                            [ Menu.item
                                [ Menu.onSelect (ChangeSelectedStatusDuration "Long") ]
                                [ text "Long" ]
                            , Menu.item
                                [ Menu.onSelect (ChangeSelectedStatusDuration "Short") ]
                                [ text "Short" ]
                            ]
                        , text model.selectedStatus.duration
                        , Menu.render Mdl
                            [ 7854627 ]
                            model.mdl
                            [ Menu.bottomLeft ]
                            [ Menu.item
                                [ Menu.onSelect (ChangeSelectedStatusLevel 1) ]
                                [ text "I" ]
                            , Menu.item
                                [ Menu.onSelect (ChangeSelectedStatusLevel 2) ]
                                [ text "II" ]
                            ]
                        , text printableLevel
                        ]
                    , Button.render Mdl
                        [ 45734857345 ]
                        model.mdl
                        [ Button.icon
                        , Options.onClick AddSelectedModelStatus
                        ]
                        [ Icon.i "library_add" ]
                    ]
               ]
        )


renderEditStatusListItem : Model -> Status -> Html Msg
renderEditStatusListItem model status =
    Lists.li []
        [ Lists.content [] [ text (statusToString status) ]
        , Button.render Mdl
            [ 134454526 ]
            model.mdl
            [ Button.icon
            , Options.onClick (RemoveSelectedModelStatus status)
            ]
            [ Icon.i "delete_forever" ]
        ]


plusMinusField : Model -> Int -> Int -> (Int -> Msg) -> Html Msg
plusMinusField model curr max currAction =
    div []
        [ Button.render Mdl
            [ 99928 ]
            model.mdl
            [ Button.icon
            , Options.onClick (currAction (curr + 1))
            ]
            [ Icon.i "keyboard_arrow_up" ]
        , Button.render Mdl
            [ 99927 ]
            model.mdl
            [ Button.icon
            , Options.onClick (currAction (curr - 1))
            ]
            [ Icon.i "keyboard_arrow_down" ]
        ]


statTextField : Model -> Int -> Int -> (Int -> Msg) -> Html Msg
statTextField model fieldId value action =
    div
        []
        [ Textfield.render Mdl
            [ model.selectedActorIdx + fieldId ]
            model.mdl
            [ Textfield.value (value |> toString)
            , Textfield.maxlength 3
            , Options.css "width" "30px"
            , Options.onInput (action << Result.withDefault 0 << String.toInt)
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
        , css
            "margin"
            ("4px 8px 4px "
                ++ (if (actortype == Player && actor.row == Front) || (actortype == Enemy && actor.row == Back) then
                        "35px"
                    else
                        "0px"
                   )
            )
        , Color.background (Color.color Color.Blue Color.S500)
        ]
        [ Card.title [ css "padding" "5px 8px 0px 8px" ] [ Card.head [ Color.text Color.white ] [ text actor.name ] ]
        , Card.text [ Color.text Color.white, css "padding" "0px 8px 8px 8px" ]
            [ div [ class "render-statcard-block" ]
                [ div [ class "render-statcard-double" ]
                    [ renderStat model "HP" actor.currentHP actor.maxHP actortype "left"
                    , renderStat model "MP" actor.currentMP actor.maxMP actortype "right"
                    ]
                , div [ class "render-statcard-double" ]
                    [ renderStat model "LP" actor.currentLP actor.maxLP actortype "left"
                    , renderStat model "Drive" actor.currentDrive actor.maxDrive actortype "right"
                    ]
                , div []
                    [ renderStatuses actor model dyn_id
                    ]
                ]
            ]
        ]


statDiv : Int -> Int -> String
statDiv c m =
    round ((toFloat c / toFloat m) * 100)
        |> toString


renderStat : Model -> String -> Int -> Int -> ActorType -> String -> Html Msg
renderStat model label currentStat maxStat actortype rorl =
    let
        span_class =
            "render-stat-" ++ rorl
    in
    span [ class span_class ]
        [ if actortype == Player then
            text (label ++ "   " ++ (toString <| currentStat) ++ "/" ++ (toString <| maxStat))
          else
            text (label ++ "   " ++ statDiv currentStat maxStat ++ "%")
        ]


renderStatuses : Actor -> Model -> Int -> Html Msg
renderStatuses actor model dyn_id =
    div [] (List.indexedMap (renderStatus model dyn_id) actor.status)


renderStatus : Model -> Int -> Int -> Status -> Html Msg
renderStatus model dyn_id idx status =
    div []
        [ Options.styled span [ Tooltip.attach Mdl [ (dyn_id * 10000) + (idx * 100) + 383874 ] ] [ i [] [ text (statusToString status) ] ]
        , Tooltip.render Mdl
            [ (dyn_id * 10000) + (idx * 100) + 383874 ]
            model.mdl
            [ Tooltip.large, Tooltip.top ]
            [ text (getTooltipFor status.status status.level) ]
        ]


tooltipsLookup =
    Dict.fromList
        [ ( ( "Energize", 1 ), "Gain +1 extra Drive at the start of your turn." )
        , ( ( "Energize", 2 ), "Gain +2 extra Drive at the start of your turn." )
        , ( ( "Focus", 1 ), "Reduce the MP cost of your abilities by half, rounded up." )
        , ( ( "Focus", 2 ), "Reduce the MP cost of your abilities to 0." )
        , ( ( "Lucky", 1 ), "When you roll a d100, lower the result by -15." )
        , ( ( "Lucky", 2 ), "When you roll a d100, lower the result by -30." )
        , ( ( "Kinetic-Power", 1 ), "Deal +2 Physical and Supreme damage." )
        , ( ( "Kinetic-Power", 2 ), "Deal +5 Physical and Supreme damage." )
        , ( ( "Elemental-Power", 1 ), "Deal +2 Fire, Water, Air and Earth damage." )
        , ( ( "Elemental-Power", 2 ), "Deal +5 Fire, Water, Air and Earth damage." )
        , ( ( "Healing-Power", 1 ), "Gain +2 potency when using HP restoring abilities." )
        , ( ( "Healing-Power", 2 ), "Gain +5 potency when using HP restoring abilities." )
        , ( ( "Kinetic-Guard", 1 ), "Reduce physical and supreme damage against you by -2." )
        , ( ( "Kinetic-Guard", 2 ), "Reduce physical and supreme damage against you by -5." )
        , ( ( "Elemental-Guard", 1 ), "Reduce Fire, Water, Air and Earth damage against you by -2." )
        , ( ( "Elemental-Guard", 2 ), "Reduce Fire, Water, Air and Earth damage against you by -5." )
        , ( ( "Stalwart", 1 ), "When someone uses a healing move on you, increase the value by +3, and gain +1 Drive." )
        , ( ( "Stalwart", 2 ), "When someone uses a healing move on you, increase the value by +6, and gain +2 Drive." )
        , ( ( "Liberation", 1 ), "You can activate a combo without expending the needed momentum." )
        , ( ( "Liberation", 2 ), "You can activate a combo without expending the needed momentum, and combo with abilities multiple times (or without spending LP, if you are a monster)." )
        , ( ( "Element-Absorb", 1 ), "You receive 0 Damage from the corresponding element." )
        , ( ( "Element-Absorb", 2 ), "You receive 0 Damage from the corresponding element, and gain +2 Drive when struck by that element." )
        , ( ( "Chill", 1 ), "Lose -1 Drive at the start of your turn." )
        , ( ( "Chill", 2 ), "Lose -2 Drive at the start of your turn." )
        , ( ( "Exhaust", 1 ), "Double your MP costs." )
        , ( ( "Exhaust", 2 ), "Triple your MP costs!" )
        , ( ( "Shock", 1 ), "When you roll a d100, increase the result by +15." )
        , ( ( "Shock", 2 ), "When you roll a d100, increase the result by +30." )
        , ( ( "Curse", 1 ), "Anytime you spend an LP, take 6 damage for each LP spent." )
        , ( ( "Curse", 2 ), "Anytime you spend an LP, take 12 damage for each LP spent." )
        , ( ( "Burning", 1 ), "At the end of your turn, take 6 damage. Cleanse with Defend." )
        , ( ( "Burning", 2 ), "At the end of your turn, take 12 damage. Cleanse with Defend." )
        , ( ( "Kinetic-Shatter", 1 ), "When you take physical or supreme damage, take +2 more." )
        , ( ( "Kinetic-Shatter", 2 ), "When you take physical or supreme damage, take +5 more." )
        , ( ( "Elemental-Shatter", 1 ), "When you take fire, water, air or earth damage, take +2 more." )
        , ( ( "Elemental-Shatter", 2 ), "When you take fire, water, air or earth damage, take +5 more." )
        , ( ( "Kinetic-Falter", 1 ), "You deal -2 physical and supreme damage." )
        , ( ( "Kinetic-Falter", 2 ), "You deal -5 physical and supreme damage." )
        , ( ( "Elemental-Falter", 1 ), "You deal -2 fire, water, air and earth damage." )
        , ( ( "Elemental-Falter", 2 ), "You deal -5 fire, water, air and earth damage." )
        , ( ( "Toxin", 1 ), "Your HP restoring abilities have -4 potency, and you take 4 damage at the end of your turn." )
        , ( ( "Toxin", 2 ), "Your HP restoring abilities have -8 potency, and you take 8 damage at the end of your turn." )
        , ( ( "Taunt", 1 ), "If you fail to target the taunting enemy, you take 6 damage." )
        , ( ( "Taunt", 2 ), "If you fail to target the taunting enemy, you take 12 damage." )
        , ( ( "Challenge", 1 ), "If you fail to target the challenging enemy, you deal -6 damage." )
        , ( ( "Challenge", 2 ), "If you fail to target the challenging enemy, you deal -12 damage." )
        ]


getTooltipFor : String -> Int -> String
getTooltipFor name level =
    case Dict.get ( name, level ) tooltipsLookup of
        Just tooltip ->
            tooltip

        Nothing ->
            "no tooltip"


statusToString : Status -> String
statusToString status =
    status.duration
        ++ " "
        ++ status.status
        ++ " "
        ++ (if status.level == 1 then
                "I"
            else
                "II"
           )
        ++ (if status.meta == "" then
                ""
            else
                ": " ++ status.meta
           )


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
