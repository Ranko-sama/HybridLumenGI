// Native temporal textures and the ordinary Release share one Editor invocation.
public static class ColorDynamicsBuild
{
    public static void Run()
    {
        DenoiseRegressionEditor.RunReactiveHistoryLimit();
        CurrentPlayerBuild.Build();
    }
}
