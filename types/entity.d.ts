import type { RecordId } from "surrealdb.js";

declare global {
  type DeveloperCredential = {
    id?: RecordId;
    name: string;
    pswd: string;
  };
  type DeveloperInfo = {
    id: RecordId;
    name: string;
  };

  type AudienceCredential = {
    id?: RecordId;
    name: string;
    pswd: string;
  };
  type AudienceInfo = {
    id: RecordId;
    name: string;
  };

  type Publisher = {
    id?: RecordId;
    name: string;
    pswd: string;
  };

  type Package = {
    id?: RecordId;
    name: string;
    publisher: RecordId;
    source?: RecordId;
    extract?: string;
    install?: RecordId;
  };
  type PackageFull = {
    id?: RecordId;
    pid: RecordId<"package">;
    name: string;
    publisher: RecordId;
    source: UnknownRecord;
    extract?: string;
    install: UnknownRecord;
  };

  type PublishPackageReq = {
    id?: RecordId;
    name: string;
  };

  type SourceGithubRaw = {
    owner: string;
    repo: string;
    v_regex: string;
  };
  type SourceGithub = {
    id?: RecordId;
    package?: RecordId<"package">;
    owner: string;
    repo: string;
    v_regex: string;
  };

  type SourceGitRaw = {
    origin: string;
  };
  type SourceGit = {
    id?: RecordId;
    package?: RecordId<"package">;
    origin: string;
  };

  type InstallExecutableRaw = {
    target: string;
    rename?: string;
  };
  type InstallExecutable = {
    id?: RecordId;
    package?: RecordId<"package">;
    target: string;
    rename?: string;
  };

  type UnknownRecord = {
    id?: RecordId;
  };
}

export {};
