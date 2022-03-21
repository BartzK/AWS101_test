#FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
#WORKDIR /app
#EXPOSE 80
#EXPOSE 443
#
#FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
#WORKDIR /src
#COPY ["AWS101.csproj", "AWS101/"]
#RUN dotnet restore "AWS101/AWS101.csproj"
#COPY . .
#WORKDIR "/src/AWS101"
#RUN dotnet build "AWS101.csproj" -c Release -o /app/build
#
#FROM build AS publish
#RUN dotnet publish "AWS101.csproj" -c Release -o /app/publish
#
#FROM base AS final
#WORKDIR /app
#COPY --from=publish /app/publish .
#ENTRYPOINT ["dotnet", "AWS101.dll"]

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build-env
WORKDIR /app
COPY . .
RUN dotnet restore
RUN dotnet publish -c Release -o out

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app
COPY --from=build-env /app/out .
RUN ["chmod", "+x", "AWS101.dll"]
ENTRYPOINT ["dotnet", "AWS101.dll"]