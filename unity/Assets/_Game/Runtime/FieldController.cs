using System;
using System.Collections.Generic;
using UnityEngine;
using Fenerbahce.Core.Economy;
using Fenerbahce.Core.Match;
using Fenerbahce.Core.Sim;

namespace Fenerbahce.Runtime
{
    /// <summary>
    /// Kontrol sahasını sürer: sabit 1/60 sn adımlı sim (30/60 FPS'de benzer sonuç), girdi toplama, olay→sunum, bitiş.
    /// </summary>
    public class FieldController : MonoBehaviour
    {
        public enum Mode { Solo, Team }

        public class Options
        {
            public Mode Mode = Mode.Solo;
            // --- Solo (kontrol sahası) ---
            public SimStats Attacker;
            public string AttackerPlayerId;
            public float KeeperSkill = 72f;
            public float DefenderLevel = 0.78f;
            public bool DefenderEnabled = true;
            // --- Takım maçı (5v5, prototip) ---
            public MatchWorldConfig Team;
            public ProfileSettings Settings;
            public string SessionId;
            public int Seed = 1;
        }

        public class Summary
        {
            public string SessionId;
            public FieldStats Stats;
            public bool Completed;
            public float PlayedSeconds;
            public bool IsTeamMatch;
            /// <summary>Olay kaydından türetilen sonuç (skor, golcüler, istatistikler).</summary>
            public Fenerbahce.Core.Match.MatchResult Result;
        }

        const float Step = 1f / 60f;
        GameApp _app; Options _o; FieldSource _src; FieldWorld _world; FieldHud _hud;
        float _acc; PlayerInput _pending; bool _finished;
        readonly List<FieldEvent> _events = new List<FieldEvent>();
        // klavye yedeği (editör/PC testi)
        float _kbPassDown = -1, _kbThroughDown = -1, _kbShootDown = -1;

        public FieldSource Source { get { return _src; } }

        public void Begin(GameApp app, Options o)
        {
            _app = app; _o = o;
            if (o.Mode == Mode.Team)
            {
                var cfg = o.Team ?? new MatchWorldConfig();
                var world = new MatchWorld(cfg);
                _src = new MatchWorldSource(world, "KANARYA", "RAKİP");
            }
            else
            {
                var cfg = new ControlFieldConfig { Seed = o.Seed, DefenderEnabled = o.DefenderEnabled, DefenderLevel = o.DefenderLevel, SessionSeconds = 120f };
                _src = new ControlFieldSource(new ControlField(cfg, o.Attacker, SimStats.Generic(o.KeeperSkill, "Kaleci")));
            }

            var worldGo = new GameObject("World"); worldGo.transform.SetParent(transform, false);
            _world = worldGo.AddComponent<FieldWorld>(); _world.Build(_src);
            var hudGo = new GameObject("Hud"); hudGo.transform.SetParent(transform, false);
            _hud = hudGo.AddComponent<FieldHud>(); _hud.Build(_src, _world, o.Settings);

            _hud.OnPass = p => { _pending.Pass = true; _pending.Power = p; };
            _hud.OnThrough = p => { _pending.ThroughPass = true; _pending.Power = p; };
            _hud.OnShoot = p => { _pending.Shoot = true; _pending.Power = p; };
            _hud.OnClear = () => { _pending.Clear = true; };
            _hud.OnSkill = d => { _pending.SkillDirection = d; };
            _hud.OnSlide = () => { _pending.Slide = true; };
            _hud.OnTackle = () => { _pending.Tackle = true; };
            _hud.OnSwitch = () => { _pending.Switch = true; };
            _hud.OnSecondDef = () => { _pending.CallSecondDefender = true; };
            _hud.OnAutoToggle = () => { _pending.ToggleAutoDefend = true; };
            _hud.OnPause = () => _hud.SetPaused(true);
            _hud.OnFinish = () => Finish(false);
            _hud.OnQuit = () => { if (_finished) return; _finished = true; _app.EndField(null); };
            _hud.Banner("SANTRA", 1.2f, Color.white);
        }

        PlayerInput BuildInput()
        {
            var inp = _pending;
            var s = _o.Settings;
            Vector2 raw = _hud.Joystick != null ? _hud.Joystick.Value : Vector2.zero;
            bool sprint = _hud.SprintHeld;
#if UNITY_EDITOR || UNITY_STANDALONE
            var kb = new Vector2((Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow) ? 1 : 0) - (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow) ? 1 : 0),
                                 (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow) ? 1 : 0) - (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow) ? 1 : 0));
            if (kb.sqrMagnitude > 0.01f) raw = kb.normalized;
            if (Input.GetKey(KeyCode.Space)) sprint = true;
            KeyHold(KeyCode.J, ref _kbPassDown, p => { inp.Pass = true; inp.Power = p; });
            KeyHold(KeyCode.K, ref _kbThroughDown, p => { inp.ThroughPass = true; inp.Power = p; });
            KeyHold(KeyCode.L, ref _kbShootDown, p => { inp.Shoot = true; inp.Power = p; });
            if (Input.GetKeyDown(KeyCode.Q)) inp.SkillDirection = -1;
            if (Input.GetKeyDown(KeyCode.E)) inp.SkillDirection = 1;
            if (Input.GetKeyDown(KeyCode.X)) inp.Slide = true;
            if (Input.GetKeyDown(KeyCode.C)) inp.Clear = true;
            if (Input.GetKeyDown(KeyCode.V)) inp.Tackle = true;
            if (Input.GetKeyDown(KeyCode.Tab)) inp.Switch = true;
            if (Input.GetKeyDown(KeyCode.R)) inp.CallSecondDefender = true;
            if (Input.GetKeyDown(KeyCode.T)) inp.ToggleAutoDefend = true;
#endif
            float mag = raw.magnitude;
            if (mag < s.JoystickDeadZone) raw = Vector2.zero;
            else raw = raw.normalized * Mathf.Clamp01(((mag - s.JoystickDeadZone) / (1f - s.JoystickDeadZone)) * s.JoystickSensitivity);
            inp.Move = new Fenerbahce.Core.Sim.Vec2(raw.x, raw.y);
            inp.Sprint = sprint;
            return inp;
        }

#if UNITY_EDITOR || UNITY_STANDALONE
        void KeyHold(KeyCode k, ref float down, Action<float> fire)
        {
            if (Input.GetKeyDown(k)) down = Time.unscaledTime;
            if (Input.GetKeyUp(k) && down >= 0) { fire(ChargeCurve.Power(Time.unscaledTime - down)); down = -1; }
        }
#endif

        void Update()
        {
            if (_finished || _src == null) return;
            if (!_hud.Paused)
            {
                _acc += Mathf.Min(Time.unscaledDeltaTime, 0.1f);
                var input = BuildInput();
                int steps = 0;
                while (_acc >= Step && steps < 6)
                {
                    _src.Step(Step, input);
                    // bir-seferlik komutlar ilk adımda tüketilir
                    input.Pass = input.ThroughPass = input.Shoot = input.Slide = false; input.SkillDirection = 0;
                    input.Clear = input.Tackle = input.Switch = input.CallSecondDefender = input.ToggleAutoDefend = false;
                    _pending = default(PlayerInput);
                    _acc -= Step; steps++;
                }
                if (steps == 6) _acc = 0f;
                _src.DrainEvents(_events);
                HandleEvents();
            }
            _world.Sync(Vector2.zero);
            if (!_finished && _src.Machine.Phase == MatchPhase.Result) Finish(true);
        }

        void HandleEvents()
        {
            foreach (var e in _events)
            {
                switch (e.Type)
                {
                    case FieldEventType.GoalScored:
                        if (_src is MatchWorldSource && e.Value != 0) { _hud.Banner("GOL (RAKİP)\n" + _src.LastGoalText, 2.4f, Ui.Danger); Buzz(120); }
                        else { _hud.Banner("GOL!\n" + _src.LastGoalText, 2.4f, Ui.Yellow); Buzz(250); }
                        break;
                    case FieldEventType.Save: _hud.Banner("KURTARIŞ!", 1.0f, Color.white); break;
                    case FieldEventType.PostHit: _hud.Banner("DİREK!", 1.0f, Color.white); break;
                    case FieldEventType.PassToTarget: _hud.Banner("HEDEFE PAS", 0.8f, new Color(0.3f, 0.85f, 1f)); break;
                    case FieldEventType.TackleWon: _hud.Banner("TOP KAZANILDI", 1.0f, Ui.Success); Buzz(60); break;
                    case FieldEventType.BallLost: _hud.Banner("TOP KAYBEDİLDİ", 1.0f, Ui.Danger); Buzz(80); break;
                    case FieldEventType.BallOut: _hud.Banner("AUT", 1.0f, Color.white); break;
                    case FieldEventType.SkillPerformed: _hud.Banner("ÇALIM", 0.6f, Ui.Yellow); break;
                    case FieldEventType.PhaseChanged:
                        if ((MatchPhase)e.Value == MatchPhase.Kickoff) _hud.Banner("SANTRA", 1.1f, Color.white);
                        else if ((MatchPhase)e.Value == MatchPhase.HalfTime) _hud.Banner("DEVRE ARASI", 2.6f, Ui.Yellow);
                        break;
                    case FieldEventType.SessionEnded: _hud.Banner("SÜRE DOLDU", 2f, Ui.Yellow); break;
                }
            }
            _events.Clear();
        }

        void Buzz(long ms)
        {
#if UNITY_ANDROID || UNITY_IOS
            if (_o.Settings.Vibration) Handheld.Vibrate();
#endif
        }

        void Finish(bool completed)
        {
            if (_finished) return;
            _finished = true;
            var m = _src.Machine;
            float played = (m.Half - 1) * m.HalfLengthSeconds + m.ElapsedInHalf;
            _app.EndField(new Summary
            {
                SessionId = _o.SessionId, Stats = _src.StatsCopy(), Completed = completed, PlayedSeconds = played,
                IsTeamMatch = _o.Mode == Mode.Team, Result = _src.BuildResult(),
            });
        }

        void OnApplicationPause(bool paused) { if (paused && _hud != null && !_finished) _hud.SetPaused(true); }
    }
}
