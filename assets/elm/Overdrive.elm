module Overdrive exposing (..)

import Array exposing (Array)
import Html exposing (..)
import Html.Attributes exposing (class, href, style)
import Json.Decode as JD
import Json.Decode.Pipeline exposing (decode, hardcoded, optional, required)
import Json.Encode as JE
import Material
import Material.Button as Button
import Material.Chip as Chip
import Material.Helpers exposing (pure)
import Material.Options as Options exposing (css)
import Material.Scheme
import Material.Slider as Slider
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


type ConnectionStatus
    = Connected
    | Disconnected
    | ScheduledReconnect { time : Time }


type alias Model =
    { momenta : List Momentum
    , selectedMomentum : Momentum
    , connectionStatus : ConnectionStatus
    , currentTime : Time
    , mdl :
        Material.Model

    -- Boilerplate: model store for any and all Mdl components you use.
    }


init : Model
init =
    { momenta = []
    , selectedMomentum = Momentum "" 0
    , connectionStatus = Disconnected
    , currentTime = 0
    , mdl =
        Material.model

    -- Boilerplate: Always use this initial Mdl model store.
    }



-- ACTION, UPDATE


type Msg
    = AddMomentum
    | RemoveMomentum Momentum
    | ClearMomentum
    | SetMomentumType String
    | SetMomentumStrength Float
    | Mdl (Material.Msg Msg)
    | Tick Time
    | MomentumUpdate JD.Value
    | SocketClosedAbnormally AbnormalClose
    | ConnectionStatusChanged ConnectionStatus



-- Boilerplate: Msg clause for internal Mdl messages.


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

        ClearMomentum ->
            let
                push =
                    Push.init "room:lobby" "clear_momentum"
                        |> Push.withPayload JE.null
            in
            model ! [ Phoenix.push lobbySocket push ]

        --( { model | momenta = [] }
        --, Cmd.none
        --)
        SetMomentumType x ->
            ( { model | selectedMomentum = Momentum x model.selectedMomentum.strength }, Cmd.none )

        SetMomentumStrength x ->
            ( { model | selectedMomentum = Momentum model.selectedMomentum.element x }, Cmd.none )

        --  Remove id ->
        --      ( { model | momenta = List.filter (\m -> m.id /= id) model.momenta }, Cmd.none )
        RemoveMomentum momentum ->
            let
                push =
                    Push.init "room:lobby" "remove_momentum"
                        |> Push.withPayload
                            (JE.object
                                [ ( "element", JE.string momentum.element )
                                , ( "strength", JE.float momentum.strength )
                                ]
                            )
            in
            model ! [ Phoenix.push lobbySocket push ]

        -- Boilerplate: Mdl action handler.
        Mdl msg_ ->
            Material.update Mdl msg_ model

        -- Recieve an updated momentum list from the server
        MomentumUpdate payload ->
            case JD.decodeValue momentaDecoder payload of
                Ok momenta ->
                    let
                        _ =
                            Debug.log "ok" momenta
                    in
                    { model | momenta = momenta } ! []

                --( model, Cmd.none )
                Err err ->
                    let
                        _ =
                            Debug.log "err" err
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


momentaDecoder : JD.Decoder (List Momentum)
momentaDecoder =
    JD.at [ "momenta" ] (JD.list momentumDecoder)


momentumDecoder : JD.Decoder Momentum
momentumDecoder =
    JD.map2 (\element strength -> Debug.log "momentum decoded: " Momentum element strength)
        (JD.field "element" JD.string)
        (JD.field "strength" JD.float)



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
        |> Channel.withDebug


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ phoenixSubscription model, Time.every Time.second Tick ]


phoenixSubscription model =
    Phoenix.connect socket [ lobby "foobie" ]



-- VIEW


type alias Mdl =
    Material.Model



{- We construct the instances of the Button component that we need, one
   for the increase button, one for the reset button. First, the increase
   button. The first three arguments are:
     - A Msg constructor (`Mdl`), lifting Mdl messages to the Msg type.
     - An instance id (the `[0]`). Every component that uses the same model
       collection (model.mdl in this file) must have a distinct instance id.
     - A reference to the elm-mdl model collection (`model.mdl`).
   Notice that we do not have to add fields for the increase and reset buttons
   separately to our model; and we did not have to add to our update messages
   to handle their internal events.
   Mdl components are configured with `Options`, similar to `Html.Attributes`.
   The `Options.onClick Increase` option instructs the button to send the `Increase`
   message when clicked. The `css ...` option adds CSS styling to the button.
   See `Material.Options` for details on options.
-}


view : Model -> Html Msg
view model =
    Material.Scheme.top <|
        div []
            [ renderMomenta model.momenta
            , div []
                [ addMomentumInput model
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


addMomentumInput : Model -> Html Msg
addMomentumInput model =
    div []
        [ div []
            [ makeMomentumRadio model 2 "Fire"
            , makeMomentumRadio model 3 "Water"
            , makeMomentumRadio model 4 "Earth"
            , makeMomentumRadio model 5 "Air"
            ]
        , div []
            [ makeMomentumRadio model 6 "Launch"
            , makeMomentumRadio model 7 "Pin"
            , makeMomentumRadio model 8 "Rush"
            ]
        , div []
            [ makeMomentumRadio model 9 "Recovery"
            , makeMomentumRadio model 10 "Supreme"
            ]
        , div []
            [ Slider.view
                [ Slider.onChange SetMomentumStrength
                , Slider.value model.selectedMomentum.strength
                , Slider.max 10
                , Slider.min 0
                , Slider.step 1
                ]
            ]
        ]


makeMomentumRadio : Model -> Int -> String -> Html Msg
makeMomentumRadio model instance momentum =
    Toggle.radio Mdl
        [ instance ]
        model.mdl
        [ Toggle.value (momentum == model.selectedMomentum.element)
        , Toggle.group "momentumtype"
        , Toggle.ripple
        , Options.onToggle (SetMomentumType momentum)
        , Options.css "margin" "3px 3px"
        ]
        [ text momentum ]


renderMomenta : List Momentum -> Html Msg
renderMomenta momenta =
    div
        []
        [ text "Current momenta: "
        , div [] (List.map toChip momenta)
        ]


toChip : Momentum -> Html Msg
toChip momentum =
    Chip.span
        [ Options.css "margin" "5px 5px"
        , Chip.deleteIcon "cancel"
        , Chip.deleteClick (RemoveMomentum momentum)
        ]
        [ Chip.content [] [ text (printMomentum momentum) ] ]
