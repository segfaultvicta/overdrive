module Overdrive exposing (..)

import Array exposing (Array)
import Html exposing (..)
import Html.Attributes exposing (class, href, style)
import Material
import Material.Button as Button
import Material.Chip as Chip
import Material.Helpers exposing (pure)
import Material.Options as Options exposing (css)
import Material.Scheme
import Material.Slider as Slider
import Material.Toggles as Toggle


-- MODEL


type alias Momentum =
    { element : String
    , strength : Float
    , id : Int
    }


type alias Model =
    { momenta : List Momentum
    , selectedMomentum : Momentum
    , momentumIndex : Int
    , mdl :
        Material.Model

    -- Boilerplate: model store for any and all Mdl components you use.
    }


model : Model
model =
    { momenta = []
    , selectedMomentum = Momentum "" 0 0
    , momentumIndex = 1
    , mdl =
        Material.model

    -- Boilerplate: Always use this initial Mdl model store.
    }



-- ACTION, UPDATE


type Msg
    = Add
    | Remove Int
    | Clear
    | SetMomentumType String
    | SetMomentumStrength Float
    | Mdl (Material.Msg Msg)



-- Boilerplate: Msg clause for internal Mdl messages.


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Add ->
            if model.selectedMomentum.element == "" then
                ( model, Cmd.none )
            else
                ( { model
                    | momenta = model.selectedMomentum :: model.momenta
                    , selectedMomentum = Momentum "" 0 model.momentumIndex
                    , momentumIndex = model.momentumIndex + 1
                  }
                , Cmd.none
                )

        Clear ->
            ( { model | momenta = [] }
            , Cmd.none
            )

        SetMomentumType x ->
            ( { model | selectedMomentum = Momentum x model.selectedMomentum.strength model.momentumIndex }, Cmd.none )

        SetMomentumStrength x ->
            ( { model | selectedMomentum = Momentum model.selectedMomentum.element x model.momentumIndex }, Cmd.none )

        Remove id ->
            ( { model | momenta = List.filter (\m -> m.id /= id) model.momenta }, Cmd.none )

        -- Boilerplate: Mdl action handler.
        Mdl msg_ ->
            Material.update Mdl msg_ model



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
                    [ Options.onClick Add ]
                    [ text ("Add " ++ printMomentum model.selectedMomentum) ]
                ]
            , div []
                [ Button.render Mdl
                    [ 0 ]
                    model.mdl
                    [ Options.onClick Clear
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
        , Chip.deleteClick (Remove momentum.id)
        ]
        [ Chip.content [] [ text (printMomentum momentum) ] ]



-- Load Google Mdl CSS. You'll likely want to do that not in code as we
-- do here, but rather in your master .html file. See the documentation
-- for the `Material` module for details.


main : Program Never Model Msg
main =
    Html.program
        { init = ( model, Cmd.none )
        , view = view
        , subscriptions = always Sub.none
        , update = update
        }
