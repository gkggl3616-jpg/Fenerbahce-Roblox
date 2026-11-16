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
        public class Options
        {
            public SimStats Attacker;
            public string AttackerPlayerId;
            public float KeeperSkill = 72f;
            public float DefenderLevel = 0.78f;
            public bool DefenderEnabled = true;
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
            /// <summary>Olay kaydından türetilen sonuç (skor, golcüler, istatistikler).</summary>
            public Fenerbahce.Core.Match.MatchResult Result;
        }

        const float Step = 1f / 60f;
        GameApp _app; Options _o; ControlField _sim; FieldWorld _world; FieldHud _hud;
        float _acc; PlayerInput _pending; bool _finished;
        readonly List<FieldEvent> _events = new List<FieldEvent>();
        // klavye yedeği (editör/PC testi)
        float _kbPassDown = -1, _kbThroughDown = -1, _kbShootDown = -1;

        public ControlField Sim { get { return _sim; } }

        public void Begin(GameApp app, Options o)
        {
            _app = app; _o = o;
            var cfg = new ControlFieldConfig { Seed = o.Seed, DefenderEnabled = o.DefenderEnabled, DefenderLevel = o.DefenderLevel, SessionSeconds = 120f };
            _sim = new ControlField(cfg, o.Attacker, SimStats.Generic(o.KeeperSkill, "Kaleci"));

            var worldGo = new GameObject("World"); worldGo.transform.SetParent(transform, false);
            _world = worldGo.AddComponent<FieldWorld>(); _world.Build(_sim);
            var hudGo = new GameObject("Hud"); hudGo.transform.SetParent(transform, false);
            _hud = hudGo.AddComponent<FieldHud>(); _hud.Build(_sim, _world, o.Settings, o.Attacker.DisplayName);

            _hud.OnPass = p => { _pending.Pass = true; _pending.Power = p; };
            _hud.OnThrough = p => { _pending.ThroughPass = true; _pending.Power = p; };
            _hud.OnShoot = p => { _pending.Shoot = true; _pending.Power = p; };
            _hud.OnSkill = d => { _pending.SkillDirection = d; };
            _hud.OnSlide = () => { _pending.Slide = true; };
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
            if (_finished || _sim == null) return;
            if (!_hud.Paused)
            {
                _acc += Mathf.Min(Time.unscaledDeltaTime, 0.1f);
                var input = BuildInput();
                int steps = 0;
                while (_acc >= Step && steps < 6)
                {
                    _sim.Step(Step, input);
                    // bir-seferlik komutlar ilk adımda tüketilir
                    input.Pass = input.ThroughPass = input.Shoot = input.Slide = false; input.SkillDirection = 0;
                    _pending = default(PlayerInput);
                    _acc -= Step; steps++;
                }
                if (steps == 6) _acc = 0f;
                _sim.DrainEvents(_events);
                HandleEvents();
            }
            _world.Sync(Vector2.zero);
            if (!_finished && _sim.Machine.Phase == MatchPhase.Result) Finish(true);
        }

        void HandleEvents()
        {
            foreach (var e in _events)
            {
                switch (e.Type)
                {
                    case FieldEventType.GoalScored:
                        _hud.Banner("GOL!\n" + _o.Attacker.DisplayName + "  " + _sim.Machine.DisplayMinute + "'", 2.4f, Ui.Yellow); Buzz(250); break;
                    case FieldEventType.Save: _hud.Banner("KURTARIŞ!", 1.0f, Color.white); break;
                    case FieldEventType.PostHit: _hud.Banner("DİREK!", 1.0f, Color.white); break;
                    case FieldEventType.PassToTarget: _hud.Banner("HEDEFE PAS", 0.8f, new Color(0.3f, 0.85f, 1f)); break;
                    case FieldEventType.TackleWon: _hud.Banner("TOP KAZANILDI", 1.0f, Ui.Success); Buzz(60); break;
                    case FieldEventType.BallLost: _hud.Banner("TOP KAYBEDİLDİ", 1.0f, Ui.Danger); Buzz(80); break;
                    case FieldEventType.BallOut: _hud.Banner("AUT", 1.0f, Color.white); break;
                    case FieldEventType.SkillPerformed: _hud.Banner("ÇALIM", 0.6f, Ui.Yellow); break;
                    case FieldEventType.PhaseChanged:
                        if ((MatchPhase)e.Value == MatchPhase.Kickoff) _hud.Banner("SANTRA", 1.1f, Color.white);
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
            var st = _sim.Stats;
            var copy = new FieldStats { Goals = st.Goals, Shots = st.Shots, ShotsOnTarget = st.ShotsOnTarget, Saves = st.Saves, TargetPasses = st.TargetPasses, Passes = st.Passes, TacklesWon = st.TacklesWon, TacklesMissed = st.TacklesMissed, BallLosses = st.BallLosses, Skills = st.Skills };
            _app.EndField(new Summary { SessionId = _o.SessionId, Stats = copy, Completed = completed, PlayedSeconds = _sim.Machine.ElapsedInHalf, Result = _sim.BuildResult() });
        }

        void OnApplicationPause(bool paused) { if (paused && _hud != null && !_finished) _hud.SetPaused(true); }
    }
}
