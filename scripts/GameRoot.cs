using Godot;

public partial class GameRoot : Node
{
    [Export] private NodePath _titleLabelPath;
    [Export] private NodePath _storyLabelPath;
    [Export] private NodePath _statusLabelPath;
    [Export] private NodePath _startButtonPath;
    [Export] private NodePath _nextButtonPath;
    [Export] private NodePath _restartButtonPath;
    [Export] private NodePath _quitButtonPath;

    private readonly string[] _storyLines =
    [
        "Godot 4.6 版重写完成测试。",
        "旧框架已移除，保留了最小可运行结构。",
        "你可以在这个版本上继续实现章节、对话和动画系统。"
    ];

    private Label _titleLabel;
    private Label _statusLabel;
    private RichTextLabel _storyLabel;
    private Button _startButton;
    private Button _nextButton;
    private Button _restartButton;
    private Button _quitButton;

    private int _index;

    public override void _Ready()
    {
        _titleLabel = GetNode<Label>(_titleLabelPath);
        _storyLabel = GetNode<RichTextLabel>(_storyLabelPath);
        _statusLabel = GetNode<Label>(_statusLabelPath);
        _startButton = GetNode<Button>(_startButtonPath);
        _nextButton = GetNode<Button>(_nextButtonPath);
        _restartButton = GetNode<Button>(_restartButtonPath);
        _quitButton = GetNode<Button>(_quitButtonPath);

        _startButton.Pressed += OnStartGame;
        _nextButton.Pressed += OnNextLine;
        _restartButton.Pressed += OnRestart;
        _quitButton.Pressed += OnQuit;

        EnterMenuState();
    }

    public override void _ExitTree()
    {
        if (IsInstanceValid(_startButton))
            _startButton.Pressed -= OnStartGame;
        if (IsInstanceValid(_nextButton))
            _nextButton.Pressed -= OnNextLine;
        if (IsInstanceValid(_restartButton))
            _restartButton.Pressed -= OnRestart;
        if (IsInstanceValid(_quitButton))
            _quitButton.Pressed -= OnQuit;
    }

    private void EnterMenuState()
    {
        _index = 0;
        _storyLabel.Text = "点击开始进入测试剧情。";
        _statusLabel.Text = "状态：待开始";
        _startButton.Visible = true;
        _nextButton.Visible = false;
        _restartButton.Visible = false;
    }

    private void EnterPlayState()
    {
        _statusLabel.Text = "状态：对话进行中";
        _startButton.Visible = false;
        _nextButton.Visible = true;
        _restartButton.Visible = false;
        _index = 0;
        ShowCurrentLine();
    }

    private void ShowCurrentLine()
    {
        if (_index < _storyLines.Length)
        {
            _storyLabel.Text = $"[{_index + 1}/{_storyLines.Length}] {_storyLines[_index]}";
        }
        else
        {
            _storyLabel.Text = "剧情结束。";
            _nextButton.Visible = false;
            _restartButton.Visible = true;
            _statusLabel.Text = "状态：结束";
        }
    }

    private void OnStartGame()
    {
        _titleLabel.Text = "Nova 4.6 Rewrite";
        EnterPlayState();
    }

    private void OnNextLine()
    {
        ++_index;
        ShowCurrentLine();
    }

    private void OnRestart()
    {
        EnterMenuState();
    }

    private void OnQuit()
    {
        GetTree().Quit();
    }
}
